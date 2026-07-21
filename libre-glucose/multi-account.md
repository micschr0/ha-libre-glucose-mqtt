<!-- doc-review: 2026-07-21 -->

# Multi-account setup

Poll **multiple LibreLink Up accounts or patients** from a single add-on instance. Use this when you follow more than one person with LibreLink Up, or manage multiple LibreView accounts across different regions. Each account becomes a named source with its own MQTT topic path.

Single account? Use the [single-account options](configuration.md) — `llu_accounts` is for two or more. When `llu_accounts` is non-empty it **supersedes** the single-account `llu_email`, `llu_password`, `llu_region`, `llu_patient_id`, `llu_timezone`, and `llu_version` fields.

## Quick start

1. Add `llu_accounts` to the add-on options panel.
2. For each account, set a unique `name`, `email`, `password`, `region`, and `timezone`.
3. Set `patient_id` only if the account has multiple patient connections — leave it empty otherwise.
4. Update your Home Assistant automations and dashboard cards to target `<prefix>/<name>/glucose` instead of the shared `<prefix>/glucose`.
5. Restart the add-on.

Minimal two-account config:

```yaml
llu_accounts:
  - name: alex
    email: alex@example.com
    password: "hunter2"
    region: EU
    timezone: Europe/Berlin
  - name: sam
    email: sam@example.com
    password: "correct-horse"
    region: US
    timezone: America/New_York
    patient_id: "00000000-0000-0000-0000-000000000001"
```

This is an **illustrative** example — credentials and UUIDs are placeholders. For a `gluco-hub check-config`-validated example with copy-paste automation YAML, see the [Examples](examples.md) page.

## Account fields

Each entry in `llu_accounts` accepts the following fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Source label. Used as the per-source MQTT topic segment — see [MQTT topics](#mqtt-topics) below. Must be unique within the list. |
| `email` | string (email) | yes | LibreLink Up account email for this patient. |
| `password` | string | yes | LibreLink Up account password. Never written to MQTT or logs. |
| `region` | enum | yes | Regional API endpoint. Must match the LibreView account region. Options: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `US`, `LA`, `RU`, `CN`. |
| `patient_id` | string | no | Patient UUID. Required only if the account has multiple connections. Leave empty to use the first connection. |
| `timezone` | IANA TZ string | yes | The patient's local timezone (e.g. `Europe/Berlin`). LibreLink Up timestamps are in local wall-clock time with no UTC offset; without this, times appear shifted. |
| `version` | string | no | LibreLink Up app-version header sent to the API. Leave empty to use the upstream default. |

## MQTT topics

> [!WARNING]
> This is the most common multi-account support issue. With `llu_accounts`, the add-on sets `per_source = true` in the upstream config. Each source publishes to its **own topic path** — `<prefix>/<name>/glucose`. The shared `<prefix>/glucose` topic is **not published** in multi-account mode — existing automations targeting that topic will receive no data.

For the example above, assuming the default `topic_prefix: gluco-hub/ha`, the two reading topics are:

| Source | Topic |
|---|---|
| `alex` | `gluco-hub/ha/alex/glucose` |
| `sam` | `gluco-hub/ha/sam/glucose` |

Your Home Assistant automations and dashboard cards must target the per-source topic for the patient you want. The shared `<prefix>/glucose` topic is not published in multi-account mode.

The health, stats, and discovery topics remain at the prefix level (`<prefix>/_health`, `<prefix>/_stats`).

## Multi-account specifics

### Region per account

Each entry specifies its own `region`. Different accounts can target different regional API endpoints — useful when patients are registered in different countries. The region **must** match the account's LibreView region, not necessarily the patient's physical location.

### Options that don't carry over

Two single-account options do not carry over to multi-account mode. The generated TOML hard-codes `client_id = "ha"` and does not pass `glucose_unit` to discovery — readings are always published in **mg/dL** regardless of the `glucose_unit` add-on option.

## Status API

Each source also appears in the HTTP Status API. See [Status API](status-api.md) for the `/clock/state` and `/clock/events` endpoints.

## Attribution

All polling, MQTT publishing, and `per_source` topic logic is provided by upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs). This add-on only wires HA Ingress and translates the add-on options into the upstream TOML config — no polling or MQTT logic lives here.

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.
