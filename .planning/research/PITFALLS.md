# Domain Pitfalls

**Domain:** LibreLink Up glucose data bridge for Home Assistant
**Researched:** 2026-06-07

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or account termination.

### Pitfall 1: MQTT Discovery unique_id Collisions on Multi-Account

**What goes wrong:** Running two gluco-hub instances with the same `client_id` causes the MQTT discovery config messages to collide. HA's documentation states explicitly: "If two sensors have the same unique ID, Home Assistant will raise an exception." The current `unique_id` format is `gluco_hub_{client_id}_glucose` and `gluco_hub_{client_id}_trend`. Same `client_id` → same `unique_id` → HA rejects the second entity.

**Why it happens:** The current HA app config has a single `client_id` field (default `"ha"`). Adding multi-account support means either: (a) multiple HA app instances each with their own config, or (b) a single app instance with multiple accounts internally. Approach (a) requires users to manually ensure unique `client_id` values. Approach (b) requires generating or deriving unique identifiers per account.

**Consequences:** User adds a second account, deploys, and either the second set of HA entities doesn't appear (silent failure) or HA logs errors about duplicate `unique_id`. If `topic_prefix` is also shared, the two instances publish to the same `{prefix}/glucose` topic — HA sees interleaved readings from different patients on the same sensor entity, producing medically dangerous confusion.

**Prevention:** For approach (a): the `client_id` default must become account-specific (e.g., derived from the account email hash or an index suffix). For approach (b): the upstream gluco-hub-rs must support per-source MQTT prefixes and per-source `client_id`/`unique_id` derivation. At the HA app level, enforce uniqueness validation on `client_id` when multiple accounts are configured.

**Detection:** After deploying multi-account, verify two separate device entries appear in HA's MQTT integration ("Devices" tab), and each entity has a distinct `unique_id`. Check HA logs for "Platform mqtt does not generate unique IDs" warnings. Use the Mosquitto app's "Listen to topic" on `homeassistant/sensor/+/config` to verify discovery payloads carry distinct `unique_id` values.

### Pitfall 2: LibreLink Up Rate Limiting (HTTP 429)

**What goes wrong:** LibreLink Up enforces rate limiting with HTTP 429 responses carrying a `Retry-After` header. The upstream gluco-hub-rs does NOT handle 429 specially — it treats any non-401 non-200 status as `LLU002` (generic status error). Multiple accounts from the same IP multiply the request rate (~2-3 HTTP calls per poll cycle per account, plus a re-login on token expiry), dramatically increasing the risk of hitting the rate limit.

**Why it happens:** The upstream `LluAuthClient` checks only for 401 (token expiry) and treats everything else as a generic error. The PyLibreLinkUp Python library explicitly handles `429` and exposes `retry_after`. The upstream gluco-hub-rs has no `Retry-After` header parsing and no 429→backoff path. LLU's rate limit thresholds are undocumented (unofficial API) but likely per-IP, meaning multiple accounts from the same HA instance share the same rate-limit bucket.

**Consequences:** Under rate limiting: every poll cycle for every account fails for the duration of the rate-limit window. This means ALL accounts lose data, not just the "newest" one. The poller retries on the next interval without backoff, potentially extending the rate-limit window. In the worst case, one account triggers the limit and all accounts starve until the window expires.

**Prevention:**
1. **Account-level request budgeting** — if supporting N accounts, reduce per-account poll frequency or stagger polls so they don't all fire simultaneously.
2. **Staggered polling** — offset each account's poll cycle by `poll_interval / N` seconds so requests are spread across the interval, not bunched.
3. **429-aware backoff** — patch upstream gluco-hub-rs to parse `Retry-After` on 429 responses and skip polls until the window expires. This prevents the "retry makes it worse" spiral.
4. **Sequential, not parallel, API calls** — when fetching for multiple accounts, serialize the API calls so at most one HTTP request is in-flight to LLU at any time.

**Detection:** Monitor `cgm_source_fetch_errors_total{error_code="LLU002"}` — a sudden spike across all configured accounts is the rate-limit signature. LLU 429 responses carry a JSON body with `status: <non-zero>` which maps to `LLU002`. The upstream does not distinguish 429 from other non-zero status values, so LLU002 spikes can also indicate auth problems; cross-reference with `LLU003` (invalid credentials) and `LLU008` (token rejection).

### Pitfall 3: Token/Session Starvation Across Multiple LLU Accounts

**What goes wrong:** Each LibreLink Up account login produces a bearer token + account-id hash with a finite expiry (typically ~1 hour). The current architecture runs one gluco-hub process → one `LluSource` → one token cache. Multi-account support requires either N processes (each with one token cache) or a single process with N token caches. If the multi-account design reuses a single token across accounts (by accident — same `Arc<Mutex<Option<LluTokens>>>` for all accounts), the last account to log in overwrites previous tokens, causing authentication failures for other accounts.

**Why it happens:** The upstream `LluSource` holds one `Arc<Mutex<Option<LluTokens>>>`. A naive multi-account implementation might share this across account instances. Even with correct per-account token isolation, the mutex is held during login (concurrent callers share one re-login round-trip). If accounts A and B both need re-login simultaneously, they contend on the same mutex — but if they're different accounts, locking them together is incorrect (different credentials, different regions).

**Consequences:** With shared token cache: account A's login overwrites account B's token → account B's next API call gets 401 → B re-logs in → A's token is overwritten → infinite ping-pong of re-authentication. This burns API calls, increases rate-limit risk, and produces gaps in data for both accounts.

**Prevention:** Each LLU account MUST have its own isolated `LluCredentials` + `LluTokens` pair with independent expiry tracking. If using a single `LluAuthClient` (shared HTTP client pool), ensure the client is reused (connection pooling is per-host, which varies by region) but tokens are per-account. The upstream token-cache mutex must be per-account, not global.

**Detection:** Monitor `cgm_source_fetch_errors_total{error_code="LLU008"}` (token rejection). Token rejection spikes alternating between accounts indicate a shared-token bug. Also check that `account_id_prefix` in logs alternates between different prefixes for different accounts.

### Pitfall 4: LibreLink Up API Breaking Changes (Version Header + Field Renames)

**What goes wrong:** LibreLink Up is an unofficial, undocumented API. Abbott can change the `version` header requirement, rename JSON fields, or change endpoint paths at any time without notice. The upstream gluco-hub-rs pins `LLU_VERSION = "4.17.0"` and the iOS `product = "llu.ios"` header. When LibreView's WAF (Web Application Firewall) raises the minimum accepted version, the bridge starts getting auth failures.

**Why it happens:** The `version` header mimics a real LibreLinkUp mobile app. Abbott's WAF inspects this and rejects outdated versions. The nightscout-librelink-up project (285 stars, most popular LLU bridge) exposes `LINK_UP_VERSION` as a configurable env var precisely because operators have encountered this. Field renames: the upstream uses `#[serde(rename)]` for every field, so a field rename in the LLU JSON would cause a deserialization failure (`LLU004`).

**Consequences:** Version rejection: login fails with status 2 or HTTP 401/403, mapped to `LLU003` (invalid credentials) or `LLU002`. Field rename: deserialization fails, mapped to `LLU004` (protocol error). Both are hard failures — all accounts stop receiving data until a fix is deployed.

**Prevention:**
1. **Version override** — the upstream already supports `GLUCO_HUB__SOURCE__LLU__VERSION`. The HA app must expose this as a config option (currently not in `config.yaml` schema) so operators can bump it without waiting for a release.
2. **Proactive monitoring** — track the `version` header used by the official LibreLinkUp app (APK teardown / App Store version history) to detect required bumps before users report failures.
3. **Field aliases** — the upstream wire types could use `#[serde(alias = "oldFieldName")]` for known historical field names as a defense-in-depth measure. Currently not implemented — any rename is a hard break.
4. **Unknown field tolerance** — the upstream already drops unknown fields (no `deny_unknown_fields`). This is correct and protects against ADDED fields, but does NOT protect against RENAMED fields.

**Detection:** Monitor `cgm_source_fetch_errors_total{error_code="LLU003"}` (auth) and `LLU004` (protocol). A sudden spike in LLU003 across many users simultaneously is the version-rejection signature. LLU004 spikes indicate schema changes. Maintain a community monitoring channel (e.g., the nightscout-librelink-up issue tracker, Diabetes DIY forums) for early warning of LLU API changes.

### Pitfall 5: JSON Schema Drift — Silent Data Loss on Field Renames

**What goes wrong:** The upstream gluco-hub-rs wire types use serde with explicit `#[serde(rename)]` mappings. If LibreLink Up renames a critical field (e.g., `ValueInMgPerDl` → `glucoseValueMgDl`), serde skips the field (it's not recognized, and `deny_unknown_fields` is not set) and the field gets its Rust default: `f64::default()` = `0.0` for `value_in_mg_per_dl`, or `None` for `Option` fields. This produces readings with glucose = 0.0 mg/dL — silently wrong, not loudly broken.

**Why it happens:** The intentional design choice to drop unknown fields (rather than rejecting them) protects against ADDED fields breaking the parser. But this same choice means RENAMED fields produce default values instead of parse errors. The `GlucoseMgDl::new(0.0)` constructor would reject 0.0 as out-of-range (valid range is typically 20–500 mg/dL), so the reading would fail to construct — but users would see `cgm_source_fetch_errors_total` increase, not a wrong value on their dashboard.

**Consequences:** If the `ValueInMgPerDl` rename produces `0.0`, the glucose value validation rejects it → reading skipped → data gap. If a non-validated field like `TrendArrow` is renamed, `trend_arrow: None` → `Trend::NotComputable` → trend entity shows "NotComputable" permanently. The `Timestamp` field rename would be caught by the timestamp parser (bad format → `LLU007`). The `patientId` rename would cause the patient lookup to fail.

**Prevention:**
1. **Schema snapshot tests** — capture a real LLU API response as a golden file and validate deserialization in CI. Any field rename that causes data loss would fail the test.
2. **Non-zero glucose assertion** — the upstream already rejects out-of-range glucose values. Ensure the rejection is logged at WARN level and surfaced in metrics (currently `LLU004`).
3. **TrendArrow validation** — a permanent `NotComputable` on all readings could be detected by a watchdog: if N consecutive readings all have `NotComputable` trend, alert.
4. **Defensive parsing** — for critical fields, consider `#[serde(alias = "oldName")]` after any observed rename to maintain backward compatibility. Document each alias with the date added and the LLU app version that introduced the rename.

**Detection:** Monitor `cgm_glucose_mgdl` gauge — if it drops to zero or stops updating for an account, investigate. Track `LLU004` and `LLU007` spikes. Compare the `_patients` MQTT topic output against expected values.

### Pitfall 6: HA MQTT Topic Name Collisions with Two Sensors

**What goes wrong:** The MQTT topic space has three collision surfaces: (a) `{topic_prefix}/glucose` — the state topic for glucose readings, (b) `{topic_prefix}/_health` — the availability topic, (c) `homeassistant/sensor/gluco_hub_{client_id}_*/config` — the discovery topics. If two instances share any of these, readings interleave, availability toggles conflict, and entities get confused.

**Why it happens:** The current single-account design uses a single `topic_prefix` (default `gluco-hub/ha`) and `client_id` (default `ha`). For multi-account, these MUST be unique per account. The HA app `config.yaml` schema validates `client_id` as `match(^[A-Za-z0-9_-]{1,23}$)` but does not validate uniqueness across instances.

**Consequences:**
- **Shared `topic_prefix`:** Instance A publishes `mgdl=120` for Patient 1. Instance B publishes `mgdl=95` for Patient 2. Both on `gluco-hub/ha/glucose`. HA's sensor entity sees alternating values from different patients — medically dangerous if used for alerts or dosing decisions.
- **Shared `_health`:** Instance A publishes `online: true`. Instance B goes offline and its LWT publishes `online: false` on the SAME topic. Instance A's entity incorrectly shows unavailable.
- **Shared discovery topics:** The second instance's retained discovery message overwrites the first's. HA sees two entities with the same `unique_id` and raises an exception — at least this fails loudly rather than silently.

**Prevention:**
1. **Per-account `topic_prefix`** — derive from account identity (e.g., `gluco-hub/{account_hash}` or `gluco-hub/{display_name}`). The HA app must enforce this isolation.
2. **Per-account `client_id`** — similarly derived. The 23-char MQTT v5 limit constrains hash length.
3. **Config validation** — if the HA app supports multiple accounts in a single config, validate that `topic_prefix` and `client_id` are unique across accounts.
4. **Upstream gluco-hub-rs change** — the upstream currently takes a single `[sink.mqtt]` block. Multi-account requires either multiple sink blocks (one per source) or a single sink that publishes per-source topics.

**Detection:** Use Mosquitto's "Listen to topic" on `gluco-hub/#` and verify topics are per-account. Check that no two published readings on the same topic have different `patient` fields. In HA, verify each patient appears as a separate device with separate entities.

## Moderate Pitfalls

### Pitfall 7: Resource Exhaustion on Raspberry Pi with Multiple Instances

**What goes wrong:** Running N instances of gluco-hub (one per account) multiplies resource usage: N tokio runtimes, N reqwest connection pools, N MQTT client connections, N DLQ files, N poll loop tasks. On resource-constrained HA hardware (Raspberry Pi 3 with 1 GB RAM, Pi Zero 2 with 512 MB), this can push the system into OOM or CPU starvation.

**Why it happens:** A single gluco-hub instance is lightweight (~15-25 MB RSS for the Rust binary + tokio runtime + reqwest pool). But each instance runs its own async runtime with its own thread pool. Two instances = 2x memory, 2x CPU for poll cycles, 2x MQTT connections. On a Pi 3 (1 GB), HA Supervisor + Mosquitto + gluco-hub already use ~400-500 MB. Two gluco-hub instances add ~30-50 MB, which is manageable. But on a Pi Zero 2 (512 MB), the margin is tight.

**Consequences:** Out-of-memory: the Linux OOM killer terminates a gluco-hub process, causing data gaps. CPU starvation: poll cycles for all accounts slow down because the tokio worker threads compete for the single CPU core, causing polls to overlap and increasing rate-limit risk.

**Prevention:**
1. **Single process, multiple accounts** — the most resource-efficient approach: one gluco-hub process with N `Source` instances and N `Sink` instances, sharing one tokio runtime, one reqwest client pool, one MQTT connection. This requires upstream architectural changes but is the correct long-term solution.
2. **Per-instance resource limits** — if using multiple HA app instances, set Docker memory limits per container.
3. **Sequential polling** — if multiple accounts in one process, poll them sequentially (not in parallel) to avoid CPU spikes.
4. **Minimum hardware recommendation** — document that 2+ accounts on a Pi Zero 2 may be unreliable; recommend Pi 4 with ≥2 GB for multi-account setups.

**Detection:** Monitor `cgm_source_fetch_errors_total` for timeouts. Check HA Supervisor's system metrics for memory pressure. If `cgm_poll_cycle_duration_seconds` starts exceeding `poll_interval_secs`, polls are overlapping.

### Pitfall 8: LLU Endpoint Deprecation — Single Point of Failure

**What goes wrong:** The bridge depends on three LLU endpoints: `POST /llu/auth/login`, `GET /llu/connections`, `GET /llu/connections/{patientId}/graph`. If any endpoint is deprecated or its path changes, the bridge stops working entirely for all accounts. There is no fallback endpoint, no alternative API surface, and no offline mode.

**Why it happens:** LibreLink Up is an unofficial API reverse-engineered from the mobile app. Abbott can change it at any time. Historical precedent: the `version` header requirement was raised without notice. Endpoint path changes have not been observed yet, but the risk is real.

**Consequences:**
- **Login endpoint deprecated:** All accounts cannot authenticate. No readings at all.
- **Connections endpoint deprecated:** Cannot discover patient IDs. If using `patient_id` in config and the patient list endpoint changes (e.g., merged into the login response), existing configurations break.
- **Graph endpoint deprecated:** No historical data. The live `glucoseMeasurement` from the connections response might still work (it's the 1-min-fresh reading), but the 24h history for backfill is gone.

**Prevention:**
1. **Accept the risk** — this is an unofficial API. Document it clearly. Users accept the risk.
2. **Monitor the reverse-engineering community** — the nightscout-librelink-up, PyLibreLinkUp, and xDrip+ projects are canaries. When they break, we break shortly after. Maintain awareness.
3. **Graceful degradation** — if the graph endpoint fails, fall back to the live `glucoseMeasurement` from the connections response. The upstream already reads this field but merges it with graph data; it could be used standalone.
4. **Endpoint path configurability** — the upstream hardcodes endpoint paths. Making them configurable (env var override) would allow operators to hotfix path changes without a new binary release.
5. **Multiple data sources** — consider adding a Nightscout-as-source fallback: if LLU is down, pull the latest reading from a Nightscout instance that another bridge is still feeding. This is an architectural change but provides resilience.

**Detection:** A complete failure of all `LLU001`/`LLU002`/`LLU004` errors across all accounts simultaneously suggests an endpoint change, not a credentials issue.

### Pitfall 9: Sensor Entity Rename Breaks User Automations

**What goes wrong:** The HA MQTT discovery entity ID is derived from `unique_id`: `sensor.gluco_hub_{client_id}_glucose`. When `client_id` changes (e.g., during multi-account migration, or when a user renames it), HA creates a NEW entity with the new ID and the OLD entity becomes unavailable. Any automations, dashboards, template sensors, or scripts referencing the old entity ID break silently.

**Why it happens:** HA entity IDs are persistent based on `unique_id`. Changing `unique_id` = new entity. The old entity's history and configuration are tied to the old `unique_id`. There is no automatic migration path.

**Consequences:** User upgrades to multi-account support, `client_id` changes from `ha` to `ha-account1`, and all their dashboards show "entity not available." Alerts based on the old entity ID stop firing. This is a user-visible regression that erodes trust.

**Prevention:**
1. **Backward-compatible defaults** — the first account in a multi-account setup should keep the legacy `client_id` (e.g., `ha`). Only additional accounts get new, derived IDs.
2. **Migration documentation** — provide step-by-step instructions for updating automations and dashboards when entity IDs change.
3. **HA entity rename** — HA allows renaming entities in the UI without changing `unique_id`. If only the display name changes, automations referencing `entity_id` still break. Use `unique_id`-based references where possible.
4. **`default_entity_id`** — the HA MQTT discovery schema supports `default_entity_id` for first-time entity creation. Not helpful for migrations, but useful for controlling initial entity IDs.

**Detection:** After migration, verify all previously-existing entities still report state. Check HA's "Repairs" section for orphaned entities. Test critical automations manually.

## Minor Pitfalls

### Pitfall 10: Timezone Configuration Per-Account

**What goes wrong:** Different LibreLink Up accounts may be in different timezones (e.g., parent in Berlin monitoring child in New York). The current `llu_timezone` config is a single global value. With multi-account, each account needs its own timezone setting.

**Why it happens:** LLU timestamps are local wall-clock time without offset. Without the correct timezone, readings appear shifted by the UTC offset (e.g., a 2 PM reading in New York appears as 7 PM in HA if timezone is set to `Europe/Berlin`).

**Consequences:** Wrong timestamps cause: (a) readings appear out of order, (b) historical graphs show incorrect timing, (c) time-windowed alerts fire at wrong times, (d) data backfill/recovery aligns readings to wrong time buckets.

**Prevention:** Multi-account config must support per-account timezone. The HA app `config.yaml` schema must expand from a single `llu_timezone` to a per-account timezone field.

### Pitfall 11: Password in HA Options JSON — Supervisor Logs

**What goes wrong:** The HA app stores `llu_password` in `/data/options.json` (managed by HA Supervisor). While Supervisor encrypts this at rest, the options JSON is read by `bashio::config` and exported as `GLUCO_HUB__SOURCE__LLU__PASSWORD`. With multiple accounts, multiple passwords are stored.

**Why it happens:** Supervisor's `/data/options.json` is readable by the app container. If an attacker gains filesystem access, all passwords are plaintext. Logging `bashio::config` values: the current `run.sh` does NOT log password values, but if debug logging is enabled, care must be taken not to log passwords from additional accounts.

**Consequences:** Password exposure from Supervisor backups, snapshot exports, or debug logs.

**Prevention:** Continue using `password` type in `config.yaml` schema (already `llu_password: password`). For multi-account, use `password` type for all account passwords. Never log password values. The upstream `LluCredentials` already wraps the password in `SecretString` and redacts it from `Debug` output.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Multi-account config | Pitfall 1: MQTT unique_id collisions | Per-account `client_id` and `topic_prefix` isolation. Validate uniqueness at config load time. |
| Multi-account polling | Pitfall 2: LLU rate limiting | Stagger poll cycles. Implement 429-aware backoff. Serialize API calls per-IP. |
| Multi-account auth | Pitfall 3: Token cache isolation | Per-account `LluTokens` with independent expiry. Never share token mutex across accounts. |
| New HA app config UI | Pitfall 10: Per-account timezone | Per-account `llu_timezone` in schema. Validate IANA timezone format. |
| Multi-account deployment | Pitfall 7: Raspberry Pi resources | Document minimum hardware. Consider single-process multi-account architecture. |
| Migration from v1.0 | Pitfall 9: Entity ID changes | Keep first account's `client_id` default. Document migration path for dashboards. |
| API resilience | Pitfall 8: Endpoint deprecation | Accept risk (unofficial API). Monitor reverse-engineering community. Plan graceful degradation. |

## Sources

- **gluco-hub-rs source code** (wire.rs, auth.rs, source.rs, discovery.rs, sink.rs, error.rs) — HIGH confidence: direct source inspection of the upstream Rust binary
- **PyLibreLinkUp library** (exceptions.py, pylibrelinkup.py) — HIGH confidence: official Python client for LLU API, documents `LLUAPIRateLimitError` with `retry_after`
- **Home Assistant MQTT discovery documentation** — HIGH confidence: official HA docs cite unique_id collision as raising exception
- **nightscout-librelink-up** (285 stars) — MEDIUM confidence: confirms `version` header changes are a known operational concern; exposes `LINK_UP_VERSION` config
- **gluco-hub-rs CHANGELOG.md** — HIGH confidence: documents historical API behavior changes (trend_arrow optional, timestamp timezone handling, version header)
- **gluco-hub-rs integration tests** (mqtt.rs, ha_schema.rs) — HIGH confidence: validates discovery payload against HA schema, confirms unique_id format
- **Training data inference** on Raspberry Pi resource usage — LOW confidence: estimates based on Rust binary characteristics and general HA Supervisor resource profiles; not measured on actual hardware
