# Add-on Layer Design: Multi-Patient Support

**Phase:** 6 | **Written:** 2026-06-07

## config.yaml Schema

### Backward-compatible list approach

```yaml
# Single account (backward compat — existing v1.0 configs)
llu_email: "user@example.com"
llu_password: "secret"
llu_region: "EU"
llu_patient_id: ""

# Multi-account (new)
llu_accounts:
  - name: "alice"
    email: "alice@example.com"
    password: "secret"
    region: "EU"
    patient_id: ""
    timezone: "Europe/Berlin"
    device_name: "Alice"
    glucose_unit: "mgdl"
  - name: "bob"
    email: "bob@example.com"
    password: "secret"
    ...
```

### Schema definition

```yaml
schema:
  llu_accounts:
    - name: "str"
      email: "email"
      password: "password"
      region: "list(AE|AP|...|CN)"
      patient_id: "str?"
      timezone: "str"
      device_name: "str?"
      glucose_unit: "list(mgdl|mmol)"
```

### Detection logic (run.sh)

```bash
if bashio::var.is_empty "$(bashio::config 'llu_accounts[0].name')"; then
    MODE="single"
else
    MODE="multi"
fi
```

## run.sh TOML Generation

When MODE=multi, generate TOML instead of flat env vars:

```bash
ACCOUNT_COUNT=$(bashio::config 'llu_accounts|length')
cat > /tmp/gluco-hub.toml <<TOML
[poller]
interval_secs = ${POLL_INTERVAL_SECS}

[http]
bind = "0.0.0.0:8080"

[state]
dir = "/data/state"
TOML

for ((i=0; i<ACCOUNT_COUNT; i++)); do
    NAME=$(bashio::config "llu_accounts[${i}].name")
    cat >> /tmp/gluco-hub.toml <<TOML

[sources.${NAME}]
email = "$(bashio::config "llu_accounts[${i}].email")"
password = "$(bashio::config "llu_accounts[${i}].password")"
region = "$(bashio::config "llu_accounts[${i}].region")"
timezone = "$(bashio::config "llu_accounts[${i}].timezone")"
TOML
done

exec /usr/local/bin/gluco-hub --config /tmp/gluco-hub.toml run
```

## Per-Patient MQTT Entity Design

### Topic naming

```
gluco-hub/ha/alice/glucose     → sensor.gluco_hub_ha_alice_glucose
gluco-hub/ha/alice/_health     → availability_topic for alice
gluco-hub/ha/bob/glucose       → sensor.gluco_hub_ha_bob_glucose
gluco-hub/ha/bob/_health       → availability_topic for bob
```

### HA Discovery

Each account gets its own discovery message with:
- `unique_id`: `gluco_hub_{client_id}_{name}_glucose`
- `name`: `Gluco Hub {device_name}`
- `device.name`: `Gluco Hub - {device_name}`
- `availability_topic`: `{prefix}/{name}/_health`

### Collision Prevention

- `name` is user-assigned and validated unique within config
- `unique_id` includes `name` → guaranteed distinct per patient
- Multiple accounts with same LibreLink Up patient_id → still distinct entities (keyed on add-on account name, not LLU patient_id)
