<!-- authoring-audit: 2026-07-16 BLUF,ModePurity,ConceptBudget,Examples,Terminology -->

# Multi-account setup

The `llu_accounts` option lets you poll **multiple LibreLink Up accounts or patients** from a single add-on instance. Each entry in the list is a named source. When `llu_accounts` is non-empty it **supersedes** the single-account `llu_email`, `llu_password`, `llu_region`, `llu_patient_id`, `llu_timezone`, and `llu_version` fields.

See [Configuration](configuration.md) for the full single-account option reference.

## Account fields

Each entry in `llu_accounts` accepts the following fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Source label. Used as the per-source MQTT topic segment — see [MQTT topics (per-source)](#mqtt-topics-per-source) below. Must be unique within the list. |
| `email` | string (email) | yes | LibreLink Up account email for this patient. |
| `password` | string | yes | LibreLink Up account password. Never written to MQTT or logs. |
| `region` | enum | yes | Regional API endpoint. Must match the LibreView account region. Options: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `US`, `LA`, `RU`, `CN`. |
| `patient_id` | string | no | Patient UUID. Required only if the account has multiple connections. Leave empty to use the first connection. |
| `timezone` | IANA TZ string | yes | The patient's local timezone (e.g. `Europe/Berlin`). LibreLink Up timestamps are in local wall-clock time with no UTC offset; without this, times appear shifted. |
| `version` | string | no | LibreLink Up app-version header sent to the API. Leave empty to use the upstream default. |

## Worked example

Add-on options panel (`llu_accounts` YAML):

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

## MQTT topics (per-source)

> [!WARNING]
> This is the most common multi-account support issue. With `llu_accounts`, the add-on sets `per_source = true` in the upstream config. Each source publishes to its **own topic path** — `<prefix>/<name>/glucose`. The shared `<prefix>/glucose` topic is **not published** in multi-account mode — existing automations targeting that topic will receive no data.

For the example above, assuming the default `topic_prefix: gluco-hub/ha`, the two reading topics are:

| Source | Topic |
|---|---|
| `alex` | `gluco-hub/ha/alex/glucose` |
| `sam` | `gluco-hub/ha/sam/glucose` |

Your Home Assistant automations and dashboard cards must target the per-source topic for the patient you want. The shared `<prefix>/glucose` topic is not published in multi-account mode.

The health, stats, and discovery topics remain at the prefix level (`<prefix>/_health`, `<prefix>/_stats`).

> **Note:** Two single-account options do not carry over to multi-account mode. The generated TOML hard-codes `client_id = "ha"` and does not pass `glucose_unit` to discovery — readings are always published in mg/dL regardless of the `glucose_unit` add-on option.

## Status API

Each source also appears in the HTTP Status API. See [Status API](status-api.md) for the `/clock/state` and `/clock/events` endpoints.

## Attribution

All polling, MQTT publishing, and `per_source` topic logic is provided by upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs). This add-on only wires HA Ingress and translates the add-on options into the upstream TOML config — no polling or MQTT logic lives here.

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.
