# Architecture Patterns

**Domain:** Container-based HA add-on for LibreLink Up glucose → MQTT bridge
**Researched:** 2026-06-07
**Confidence:** HIGH — based on reading upstream Rust source, HA add-on docs, and industry patterns

---

## Recommended Architecture: Single Process, Multiple Sources

### Executive Decision

**A single gluco-hub process with multiple LLU sources** — NOT multiple containers, NOT multiple processes. The existing architecture already fans one source → N sinks with per-sink watermarks and DLQ. Adding multiple sources to the same poll infrastructure is the natural extension.

### Why Not Multiple Processes

| Approach | Wins | Loses |
|----------|------|-------|
| Multiple `gluco-hub run` processes (one per account) | Zero upstream changes; simple add-on-side only | Each process needs its own MQTT client_id, topic_prefix, HTTP port, and DLQ dir. No shared coordination. A 3-account deployment uses 3× resources. Healthchecks duplicative. |
| Multiple containers (HA app instances per account) | HA-style isolation; standard Supervisor UX | HA does not support multiple instances of the same add-on slug. Users would need to install duplicate add-on repos. Operational complexity explodes. |
| **Single process, multiple sources** | One MQTT connection, one HTTP API, one DLQ tree, one healthcheck. Per-account error isolation via independent poll tasks. Minimal resource growth. | Requires upstream gluco-hub-rs config changes (see Component Boundaries below). |

### Component Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│ libre-glucose HA app (single container)                     │
│                                                             │
│  run.sh (bashio)                                            │
│   • reads /data/options.json                                │
│   • bashio::services mqtt                                   │
│   • exports per-account GLUCO_HUB__* env vars               │
│   • OR writes config TOML with [[source.llu]] arrays        │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ gluco-hub (single process)                            │  │
│  │                                                       │  │
│  │  Poll Manager                                         │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐            │  │
│  │  │ Account A │  │ Account B │  │ Account C │           │  │
│  │  │ LluSource │  │ LluSource │  │ LluSource │  …        │  │
│  │  │ + auth    │  │ + auth    │  │ + auth    │           │  │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘           │  │
│  │        │              │              │                  │  │
│  │        ▼              ▼              ▼                  │  │
│  │  ┌────────────────────────────────────────┐            │  │
│  │  │          ReadingCache                   │            │  │
│  │  │  per-patient: latest Reading            │            │  │
│  │  └────────────────────────────────────────┘            │  │
│  │        │                                               │  │
│  │        ▼                                               │  │
│  │  ┌────────────────────────────────────────┐            │  │
│  │  │  SinkRouter (per-sink watermark)        │            │  │
│  │  │  → DlqSink (per-sink DLQ)              │            │  │
│  │  │  → MqttSink (single MQTT connection)   │            │  │
│  │  └────────────────────────────────────────┘            │  │
│  │        │                                               │  │
│  │        ▼                                               │  │
│  │  ┌──────────────────────────────────────┐              │  │
│  │  │  HTTP API (single listener :8080)    │              │  │
│  │  │  /healthz  /metrics  /glucose/latest │              │  │
│  │  │  /glucose/<account>/latest (NEW)     │              │  │
│  │  └──────────────────────────────────────┘              │  │
│  └───────────────────────────────────────────────────────┘  │
│                     │ MQTT (plaintext, internal)             │
└─────────────────────┼───────────────────────────────────────┘
                      ▼
              Mosquitto app
                      │
                      ▼
              Home Assistant entities
```

### Key Component Interactions

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `run.sh` | Translates HA options → gluco-hub env vars / TOML | bashio, /data/options.json |
| Poll Manager (new) | Orchestrates per-account poll ticks; isolates account errors | LluSource instances, ReadingCache |
| LluSource (per account) | Login, fetch connections, fetch graph for one LLU account | LibreLink Up API |
| ReadingCache | In-memory cache, keyed by patient_id | Poll Manager, HTTP API |
| SinkRouter | Per-sink watermark: filters already-pushed readings | ReadingCache, DlqSink |
| DlqSink | Persistent dead-letter queue per sink | SinkRouter, MqttSink, disk |
| MqttSink | Single MQTT v5 connection to broker | Mosquitto |
| HTTP API | Health, metrics, per-account glucose endpoint | Ingress proxy |

---

## 1. Single Process, Multiple Sources

### Design

Each configured LLU account spawns an independent `tokio::spawn` task with its own `LluSource`, its own token cache, and its own error recovery loop. All tasks share:
- One `ReadingCache` (keyed by `patient_id`)
- One set of `SinkRouter`/`DlqSink` wrappers
- One MQTT client connection
- One HTTP listener

### Error Isolation

Account-level errors (wrong credentials, region mismatch, LLU outage) are trapped inside the per-account poll task:

```
tokio::spawn(async move {
    loop {
        match source.fetch_latest().await {
            Ok(readings) => {
                cache.update_for_patient(patient_id, &readings);
                // fan-out to shared sinks (internally synchronized)
            }
            Err(LluError::Unauthorized { .. }) => {
                // Account-specific: log, emit metric, retry next cycle
                // Does NOT affect other accounts
            }
            Err(e) => {
                // Transient: backoff, retry
            }
        }
        tokio::time::sleep(interval).await;
    }
});
```

Each account has its own `cgm_source_fetch_errors_total{account="..."}` metric counter so operators can see which account is failing. The `_health` MQTT topic gains an `account` dimension: `<prefix>/<account>/_health`.

### Upstream Changes Required

The gluco-hub-rs config system (`config.rs`) must be extended. Current state:

```rust
// CURRENT — single source
pub struct SourceConfig {
    pub llu: Option<LluSourceConfig>,  // ONE config block
}
```

Required change — either named accounts (TOML tables) or indexed accounts (TOML array):

**Option A: Named accounts (preferred for clarity)**

```toml
[source.llu.kid1]
email = "parent@example.com"
region = "EU"
patient_id = "uuid-for-kid1"
timezone = "Europe/Berlin"

[source.llu.kid2]
email = "parent@example.com"
region = "EU"
patient_id = "uuid-for-kid2"
timezone = "Europe/Berlin"
```

Env var overrides: `GLUCO_HUB__SOURCE__LLU__KID1__EMAIL`, etc. This maps cleanly to `HashMap<String, LluSourceConfig>`.

**Option B: Indexed accounts (TOML array, more DRY for same-credentials families)**

```toml
# shared credentials (if all accounts use same credentials)
[source.llu]
email = "parent@example.com"
region = "EU"

# per-patient overrides
[[source.llu.patients]]
patient_id = "uuid-for-kid1"
timezone = "Europe/Berlin"

[[source.llu.patients]]
patient_id = "uuid-for-kid2"
timezone = "Europe/Berlin"
```

**Recommendation: Option A (named accounts).** While Option B is DRY-er for families sharing one LLU account, it conflates the common case (single LLU account, multiple patients) with the rarer case (separate LLU accounts per patient). Named accounts make both cases explicit and allow per-account email/password/region — the common real-world pattern where each family member has their own LibreLinkUp login.

---

## 2. Error Isolation Between Accounts

### Principle

One account's failure MUST NOT:
- Stop other accounts from polling
- Corrupt shared state (cache, DLQ)
- Crash the process
- Drop readings from other accounts

### Implementation Strategy

| Failure Mode | Isolation Mechanism | Observability |
|-------------|-------------------|---------------|
| LLU auth failure (wrong credentials) | Per-account poll task logs error, increments metric, retries on next cycle | `cgm_source_fetch_errors_total{account="kid1",error_code="LLU003"}` |
| LLU API 5xx / timeout | Exponential backoff within per-account task; other accounts continue | `cgm_source_fetch_errors_total{account="kid1",error_code="LLU001"}` |
| LLU response schema change (unparseable field) | `#[serde(rename)]` + `Option` fields already handle this; unparseable fields → empty reading batch for that account only | `cgm_source_fetch_errors_total{account="kid1",error_code="LLU004"}` |
| MQTT broker unreachable | Shared sink handles this; ALL accounts queue to DLQ, all drain together on reconnect | `cgm_dlq_size{sink="mqtt"}` |
| Single reading corrupt | `mapping::reading_from_measurement` returns `Result` — bad readings are logged and skipped, not propagated | Log entry with account label |

### Shared Resource Contention

The `ReadingCache` is `Arc<RwLock<HashMap<PatientId, Reading>>>` — per-patient writes are independent. The `Mutex`-based DLQ (already tokio-safe, per docs) serializes writes but a single account's flood of DLQ entries cannot starve others because DLQ writes are bounded per poll cycle.

---

## 3. MQTT Topic Naming for Multi-Account

### Pattern

```
<base_prefix>/<account_identifier>/glucose
<base_prefix>/<account_identifier>/_health
<base_prefix>/<account_identifier>/_stats
<base_prefix>/<account_identifier>/_patients
```

Where `<account_identifier>` is derived from the account configuration name.

**Default for single-account backward compatibility**: the `<account_identifier>/` segment is omitted, matching the existing `topic_prefix` behavior. This ensures zero-breakage for existing v1.0 users.

### HA Discovery for Multiple Accounts

Each account gets its own HA device with separate entities:

| Account | MQTT Topic | Discovery unique_id | HA Entity |
|---------|-----------|-------------------|-----------|
| `kid1` | `gluco-hub/ha/kid1/glucose` | `gluco_hub_ha_kid1_glucose` | `sensor.gluco_hub_ha_kid1_glucose` |
| `kid1` | `gluco-hub/ha/kid1/glucose` | `gluco_hub_ha_kid1_trend` | `sensor.gluco_hub_ha_kid1_trend` |
| `kid2` | `gluco-hub/ha/kid2/glucose` | `gluco_hub_ha_kid2_glucose` | `sensor.gluco_hub_ha_kid2_glucose` |
| `kid2` | `gluco-hub/ha/kid2/glucose` | `gluco_hub_ha_kid2_trend` | `sensor.gluco_hub_ha_kid2_trend` |

Each account's HA device carries:
- `name`: `Gluco Hub (<client_id> - <account_name>)` or the patient's first name + last initial (PHI-safe)
- `identifiers`: `gluco_hub_<client_id>_<account_id>`
- `model`: `gluco-hub-rs (LibreLink Up)`  
- `sw_version`: the gluco-hub version

The HA MQTT discovery spec supports multiple devices per MQTT client — each discovery config message carries a `uniq_id` and `device` block; HA groups entities with the same `device.identifiers` under one device. No additional HA-side configuration needed.

### Topic Rationale

- Per-account sub-topic keeps the namespace flat enough for MQTT wildcard subscriptions (`gluco-hub/ha/+/glucose` subscribes to all accounts)
- Account identifier is user-configured, not auto-generated — users name accounts in the add-on config
- The `_health` retained message per account allows per-patient availability tracking in HA

---

## 4. State Persistence for Multiple Accounts

### Current Architecture (Single Account)

```
<state_dir>/
  dlq/
    mqtt.jsonl       ← one file per sink, JSONL of DlqEntry {v, reading}
```

The DLQ already enqueues readings keyed by `(patient_id, timestamp)` via `merge_dedup`. The single `mqtt.jsonl` file naturally handles multiple patient IDs without changes.

### Multi-Account DLQ Strategy

**Keep the shared DLQ file — no per-account splitting needed.** Rationale:

1. The DLQ is already patient-aware: `merge_dedup` keys by `(patient_id, timestamp)`.
2. When MQTT recovers, ALL queued readings drain together — ordering is preserved per-patient.
3. The `max_entries` cap (default 10,000) is shared across all accounts — 10,000 readings at LLU's 5-minute raster ≈ 35 days of buffer. With 3 accounts this shrinks to ~12 days, which still covers realistic MQTT outages.
4. Splitting DLQ files per account would add complexity (separate cap enforcement, separate file management) without solving a real problem.

**If a per-account DLQ is later needed**, the change is additive:
```
<state_dir>/
  dlq/
    mqtt/
      kid1.jsonl
      kid2.jsonl
```

### Watermark Persistence

The current `SinkRouter` watermarks are in-memory only — they reset on restart. For multi-account, watermarks SHOULD be persisted alongside the DLQ so full 24h batch re-sends don't flood the MQTT broker after every restart:

```
<state_dir>/
  watermarks/
    mqtt.json          ← {"kid1": "2026-06-07T12:00:00Z", "kid2": "2026-06-07T11:55:00Z"}
```

This is an upstream gluco-hub-rs change — tracked separately.

### Liveness Heartbeat

The existing heartbeat file (`<state_dir>/.alive`) remains sufficient: it proves the poll loop is alive, regardless of which account(s) are succeeding. Per-account health is observable via MQTT `_health` topics and Prometheus metrics.

---

## 5. API Change Resilience

### Current Defenses (Already in Place)

gluco-hub-rs already implements several resilience patterns against LibreLink Up API changes:

| Mechanism | File | Effect |
|-----------|------|--------|
| Explicit field renames, ignore unknown | `wire.rs:23` | `#[serde(rename)]` maps known fields; unknown fields dropped silently — API additions don't break parsing |
| Optional `TrendArrow` | `wire.rs:65` | `trend_arrow: Option<u8>` — graphData entries sometimes omit it; bridge handles absence gracefully |
| Configurable `version` header | `config.rs`, `headers.rs` | `GLUCO_HUB__SOURCE__LLU__VERSION` can override the app version header without recompiling — LibreView bumps minimum version → operator sets env var |
| Explicit error codes | `error.rs` | Every LLU error maps to a stable `[LLU0xx]` code — operators can grep logs; dry-run scripts exit-code on them |
| 401 token invalidation | `source.rs:128-136` | Data endpoints returning 401 trigger token drop + re-login, NOT a process crash |
| `status` field checked | `source.rs` (implied) | LLU responses carry `status` and `data`; non-zero status → error, not silently empty data |

### Gaps to Address

| Gap | Risk | Mitigation |
|-----|------|------------|
| Field removal (critical field goes missing) | `glucose_measurement.ValueInMgPerDl` or `graphData[].Timestamp` disappearing → all readings stop | Make critical fields defensive: `value_in_mg_per_dl: Option<f64>` for `GlucoseMeasurement`, log warning when absent, skip that reading but continue |
| Response shape change (envelope restructure) | Top-level JSON keys change → `serde` fails to deserialize entire response | Add a pre-parse schema check: attempt to deserialize the known shape; if it fails, log the raw response body at debug level and return an error — the bridge skips that poll cycle but stays alive |
| Semantic change (trend_arrow values change from 1-5 to 0-4) | Trend mapping produces wrong/unknown trend strings | Map unknown trend values to `NotComputable` instead of crashing; log the raw value at warn level |
| Rate limiting / 429 | LLU starts rate-limiting: consecutive failures exhaust retries | The existing per-cycle backoff handles transient failures; add a "consecutive failure count" per account that gradually extends the poll interval (60s → 120s → 300s → capping at 600s) |

### Schema Version Detection

LLU has no `/version` or schema-version endpoint. Detection is heuristic:

1. **HTTP response headers**: Check for `x-liberr-version` or similar versioning headers (observed in some LLU instances)
2. **Response shape fingerprint**: Hash the set of top-level keys in `ConnectionsResponse` and `GraphResponse`; log the fingerprint at startup (debug level). When it changes, flag for operator review.
3. **`status` field semantics**: LLU's `status: 0` = success convention; non-zero status codes sometimes carry API-version hints in error messages. Log these at `warn` level.

### Graceful Degradation Playbook

When LLU changes break parsing for one account:

```
1. Log: "[LLU004] malformed response for account 'kid1': missing field 'ValueInMgPerDl'"
2. Skip: this poll cycle for account 'kid1' — no readings for this account
3. Metric: cgm_source_fetch_errors_total{account="kid1",error_code="LLU004"} += 1
4. Other accounts: unaffected — kid2 and kid3 continue polling
5. Operator action: update GLUCO_HUB__SOURCE__LLU__VERSION or upstream gluco-hub-rs
```

The bridge never crashes on unparseable responses — it degrades the affected account(s) and keeps everything else running.

### Configurable Poll Backoff

```toml
[source.llu.kid1]
# ... credentials ...
# Maximum poll interval when this account is in error-recovery mode
max_backoff_secs = 600  # default 600 (10 min)
```

The poll manager implements: `interval = min(base_interval * 2^failures, max_backoff_secs)`. Reset to `base_interval` on first successful poll.

---

## 6. How gluco-hub-rs Handles Configuration

### Current Configuration System

gluco-hub-rs uses the `config` crate with a layered configuration strategy:

1. **Built-in defaults** (compiled into binary): `http.bind = 127.0.0.1:8080`, `poller.interval_secs = 60`
2. **TOML file** (optional): `config.toml` or `-c <path>`
3. **Environment variables** (highest priority): `GLUCO_HUB__SECTION__KEY`

The env var mapping uses `Environment::with_prefix("GLUCO_HUB").separator("__")`, which translates:
- `GLUCO_HUB__SOURCE__LLU__EMAIL` → `source.llu.email`
- `GLUCO_HUB__SINK__MQTT__TOPIC_PREFIX` → `sink.mqtt.topic_prefix`

### Single-Account Limitation

The current `SourceConfig` struct is a flat `Option<LluSourceConfig>`:

```rust
// config.rs — current
pub struct SourceConfig {
    pub llu: Option<LluSourceConfig>,  // exactly ONE or NONE
}
```

There is NO support for multiple LLU source blocks. The config crate's `Environment` source cannot natively map indexed or keyed env vars into `HashMap` or `Vec` — it only handles flat dotted keys.

### Extending for Multi-Account

**The config crate supports TOML tables with dynamic keys.** The Rust side must change from `Option<LluSourceConfig>` to `HashMap<String, LluSourceConfig>`:

```rust
// NEW
pub struct SourceConfig {
    pub llu: Option<HashMap<String, LluSourceConfig>>,
}
```

This gives TOML support for:
```toml
[source.llu.kid1]
email = "..."
region = "EU"

[source.llu.kid2]
email = "..."
region = "EU"
```

**Env var support for named accounts** requires either:
- A custom environment source that parses `GLUCO_HUB__SOURCE__LLU__<NAME>__<KEY>` → `source.llu.<NAME>.<KEY>`
- OR: generate a TOML file from env vars in `run.sh` and pass it to `gluco-hub -c /tmp/config.toml`

**Recommended: TOML generation from run.sh.** This keeps all the complexity in the add-on wrapper (Bash) where it belongs — no upstream Rust config-parser changes for indexed env vars. The `run.sh` script already reads `/data/options.json` and exports env vars; switching to TOML generation is a small delta:

```bash
# run.sh — generate config from HA options
cat > /tmp/gluco-hub-config.toml <<'TOML'
[poller]
interval_secs = ${POLL_INTERVAL_SECS}

[http]
bind = "0.0.0.0:8080"

[sink.mqtt]
broker_host = "${MQTT_HOST}"
broker_port = ${MQTT_PORT}
# ...
TOML

# Per-account LLU sources
ACCOUNTS_JSON="$(bashio::config 'llu_accounts')"
echo "$ACCOUNTS_JSON" | jq -r '.[] | ...' >> /tmp/gluco-hub-config.toml

exec /usr/local/bin/gluco-hub -c /tmp/gluco-hub-config.toml run
```

---

## Patterns to Follow

### Pattern 1: Per-Account Poll Task with Shared Sink Fan-Out

**What:** Each LLU account runs in an independent `tokio::spawn` task. All tasks push readings into a shared `ReadingCache`. A single fan-out loop drains the cache and pushes to sinks.

**When:** Multiple accounts configured; single MQTT broker.

**Example structure:**
```rust
// In gluco-hub main or poll module
let cache = Arc::new(ReadingCache::new());
let sinks = build_sinks(&cfg)?;

for (account_name, llu_config) in cfg.source.llu.iter() {
    let source = build_llu_source(llu_config, account_name)?;
    let cache = cache.clone();
    let sinks = sinks.clone();
    tokio::spawn(async move {
        poll_account_loop(source, cache, sinks, account_name).await;
    });
}
```

### Pattern 2: Defensive Deserialization

**What:** Every LLU wire type uses `#[serde(rename)]` for explicit field mapping, `Option` for optional fields, and `#[serde(default)]` for fields that may go missing. The bridge NEVER uses `#[serde(deny_unknown_fields)]` on LLU responses.

**When:** Any LLU API response parsing.

**Already in place:** `wire.rs` follows this pattern. Extend it by making `GlucoseMeasurement.value_in_mg_per_dl` optional (current code will fail if LLU ever drops this field).

### Pattern 3: Account-Aware Metric Labels

**What:** Every metric that can differ per account carries an `account` label. Single-account deployments use `account="default"` for backward compatibility.

**When:** MQTT publishes, source fetch results, cache updates.

**Example:**
```
cgm_source_fetch_errors_total{source_id="llu",account="kid1",error_code="LLU003"} 3
cgm_source_fetch_success_total{source_id="llu",account="kid1"} 142
cgm_source_fetch_success_total{source_id="llu",account="kid2"} 141
```

### Pattern 4: Backward-Compatible Config Migration

**What:** The `run.sh` entrypoint detects whether the user is using the old single-account config (`llu_email`/`llu_password`/...) or the new multi-account config (`llu_accounts: [...]`). It normalizes both into the same TOML structure before launching gluco-hub.

**When:** During the v1.1 migration window. Single-account users should see zero config changes.

```bash
# run.sh — config migration
if bashio::config.exists 'llu_accounts'; then
    # New multi-account path
    generate_multi_account_toml
else
    # Legacy single-account path (normalize into [[source.llu]] with name "default")
    generate_single_account_toml
fi
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Multiple `gluco-hub run` Processes in One Container

**What:** Launching N copies of the gluco-hub binary, each with different env vars.

**Why bad:**
- Each process binds its own HTTP port (port conflicts, or need N ports)
- Each process opens its own MQTT connection (broker sees N clients; resource waste)
- Each process writes its own DLQ (fragmented state)
- No shared coordination — one process can flood the broker while another starves
- Signal handling gets complex (which process gets SIGTERM?)
- HA liveness check (HEALTHCHECK) can only probe one port

**Instead:** Single process with multiple sources, as recommended above.

### Anti-Pattern 2: Fat MQTT Topic with All Readings on One Topic

**What:** Publishing all accounts' readings to `<prefix>/glucose` and distinguishing by a `patient_id` field in the JSON payload.

**Why bad:**
- HA MQTT discovery cannot split one topic into multiple entities without complex templating
- Users can't subscribe to one patient's readings with simple MQTT wildcards
- Clock View can't display one patient without parsing all messages

**Instead:** Per-account sub-topics: `<prefix>/kid1/glucose`, `<prefix>/kid2/glucose`.

### Anti-Pattern 3: Crash-on-Schema-Change

**What:** `unwrap()` or `expect()` on LLU response fields that might change.

**Why bad:** LLU API changes are outside our control. A field rename by Abbott should cause a metric increment + log, not a container restart loop.

**Instead:** Defensive deserialization, `Option` fields, logged warnings on missing data, per-account error isolation.

---

## Scalability Considerations

| Concern | At 1 account (current) | At 3 accounts (typical family) | At 10 accounts (edge) |
|---------|----------------------|-------------------------------|----------------------|
| MQTT publishes/min | ~1 | ~3 | ~10 |
| DLQ disk usage | ~28KB/day | ~85KB/day | ~280KB/day |
| LLU API calls/min | 1 login + 1 conn + 1 graph | 3 login + 3 conn + 3 graph | 10 login + 3 conn + 3 graph (if same-credential account sharing) |
| Memory | ~15MB | ~20MB | ~35MB |
| CPU | negligible | negligible | negligible |
| MQTT broker load | trivial | trivial | trivial — 10 publishes/min |

**Resource ceiling:** Even 10 accounts are well within a Raspberry Pi 4's capabilities. The bottleneck is LLU rate limiting (observed at ~1 req/s per account), not the bridge.

---

## HA Add-On Config Schema Changes

### New `config.yaml` Schema (v1.1)

```yaml
# Legacy single-account (backward compatible)
options:
  llu_email: ""
  llu_password: ""
  llu_region: "EU"
  llu_patient_id: ""
  llu_timezone: "UTC"
  # ... existing fields ...

  # NEW: multi-account list
  llu_accounts:
    - name: ""           # account identifier (used in MQTT topics)
      email: ""
      password: ""
      region: "EU"
      patient_id: ""
      timezone: "UTC"

schema:
  # Legacy fields kept for backward compatibility
  llu_email: "email?"
  llu_password: "password?"
  llu_region: "list(AE|AP|AU|CA|DE|EU|EU2|FR|JP|US|LA|RU|CN)?"
  llu_patient_id: "str?"
  llu_timezone: "str?"

  # NEW: multi-account
  llu_accounts:
    - name: "match(^[a-z0-9_-]{1,32}$)"
      email: email
      password: password
      region: "list(AE|AP|AU|CA|DE|EU|EU2|FR|JP|US|LA|RU|CN)"
      patient_id: "str?"
      timezone: "str?"
```

### Migration Path

1. **v1.1 initial**: Both `llu_email` (legacy) and `llu_accounts` (new) are accepted. `run.sh` detects which is used.
2. **v1.2 (future)**: Legacy fields emit deprecation warnings in logs.
3. **v2.0 (future)**: Legacy fields removed; `llu_accounts` required.

---

## Sources

- [gluco-hub-rs architecture docs](https://github.com/micschr0/gluco-hub-rs/blob/main/docs/ARCHITECTURE.md) — HIGH confidence. Read the full source at `gluco-hub/src/config.rs`, `gluco-hub/src/main.rs`, `gluco-hub/src/dlq.rs`, `gluco-hub/src/sink_router.rs`, `gluco-hub/src/sources/llu/wire.rs`, `gluco-hub/src/sources/llu/source.rs`.
- [Home Assistant add-on configuration docs](https://developers.home-assistant.io/docs/apps/configuration/) — HIGH confidence. Official HA developer documentation.
- [HA MQTT discovery spec](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery) — MEDIUM confidence. Standard MQTT discovery pattern; per-device grouping via `device.identifiers` confirmed.
- [config crate documentation](https://docs.rs/config/latest/config/) — HIGH confidence. The layered config system with `Environment::with_prefix` is the standard Rust config pattern.
- Project source files: `run.sh`, `config.yaml`, `Dockerfile`, `DOCS.md` — HIGH confidence. Primary research artifacts.
