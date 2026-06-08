# Multi-Source Specification: gluco-hub-rs

**Written:** 2026-06-07
**Phase:** 6 — Multi-Patient Support
**Status:** Specification for upstream coordination

## Goal

Extend gluco-hub-rs from single-account polling to multi-account polling, enabling one add-on instance to monitor multiple LibreLink Up patients or accounts with isolated MQTT entities per patient.

## Architecture

### Config Change

```rust
// Current (single-source)
pub struct AppConfig {
    pub source: SourceConfig,
    pub poller: PollerConfig,
    pub http: HttpConfig,
    pub sink: SinkConfig,
    pub state: Option<StateConfig>,
}

pub struct SourceConfig {
    pub llu: Option<LluSourceConfig>,
}

// Proposed (multi-source)
pub struct AppConfig {
    pub sources: HashMap<String, LluSourceConfig>,  // named accounts
    pub poller: PollerConfig,
    pub http: HttpConfig,
    pub sinks: HashMap<String, SinkConfig>,  // per-account sinks
    pub state: Option<StateConfig>,
}
```

### Per-Source Isolation

Each named source gets:
- **Own token cache** — `HashMap<String, Arc<Mutex<Option<LluTokens>>>>`
- **Own poll task** — `tokio::spawn(poll_account(name, config, sinks, tokens))`
- **Own sink** — MQTT topics scoped per account (`<prefix>/<account_name>/glucose`)
- **Own DLQ** — indexed by account name

### MQTT Topic Naming

```
Current:  gluco-hub/ha/glucose
Proposed: gluco-hub/ha/alice/glucose
          gluco-hub/ha/bob/glucose
```

Each account gets its own topic prefix. MQTT discovery messages use distinct `unique_id`:
```
gluco_hub_ha_alice_glucose
gluco_hub_ha_bob_glucose
```

### Error Isolation

- One account's login failure (wrong credentials, region mismatch) → only that account goes offline
- One account's HTTP 429 → only that account backs off, others continue
- Shared MQTT connection — connection failure affects all accounts (acceptable, same broker)

## Config Format (TOML)

```toml
[sources.alice]
email = "alice@example.com"
password = "secret"
region = "EU"
patient_id = ""
timezone = "Europe/Berlin"
version = ""

[sources.bob]
email = "bob@example.com"
password = "secret"
region = "EU"
patient_id = "abc123"
timezone = "Europe/Berlin"

[sinks.alice]
mqtt_broker_host = "mqtt.local"
mqtt_broker_port = 1883
mqtt_client_id = "gluco-hub-alice"
mqtt_username = "mosquitto"
mqtt_password = "secret"
mqtt_topic_prefix = "gluco-hub/ha/alice"
mqtt_discovery_enabled = true
mqtt_discovery_prefix = "homeassistant"
mqtt_discovery_unit = "mgdl"
mqtt_device_name = "Alice"

[sinks.bob]
# ... per-account sink config
```

## Backward Compatibility

When only one account is configured, the TOML uses legacy flat config:
```toml
[source.llu]
email = "..."
password = "..."
```

The app detects single-account vs multi-account config and uses the appropriate code path. Single-account behavior is identical to current v1.x.

## Acceptance Criteria

1. N named accounts in config → N poll tasks spawned
2. Each account publishes to `<prefix>/<name>/glucose`
3. Each account has distinct MQTT discovery unique_id
4. One account's 401/429 error does not block other accounts
5. Single-account config behaves identically to v1.x (regression test)
6. Token cache isolation: logging out account A does not invalidate account B's session
