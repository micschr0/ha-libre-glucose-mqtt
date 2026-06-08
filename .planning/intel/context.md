# Context

**Source type:** All 5 documents classified as DOC (documentation).  
Extracted notes organized by topic with source attribution.

---

## Project Identity

- Repo name: `ha-libre-glucose-mqtt` → slug in config.yaml is `libre-glucose`
- Terminology: HA developer docs renamed "add-on" → "app" in 2025. User-facing UI still says "add-on" in many places. Schema fields and CI action names intentionally keep "addon"/"add-on".
  - Source: `libre-glucose/DOCS.md`, `README.md` (root), `libre-glucose/CHANGELOG.md`
- GitHub Pages at https://micschr0.github.io/ha-libre-glucose-mqtt/ with Cayman theme. Landing page is root `README.md`.
  - Source: `libre-glucose/CHANGELOG.md` (2026.516.0)

## Capabilities

### Polling + MQTT
- Every `poll_interval_secs` (default 60s): login to LibreLink Up → fetch latest reading → publish to MQTT.
- MQTT topics: `<prefix>/glucose`, `<prefix>/_health`, `<prefix>/_stats`, `<prefix>/_patients`. Default prefix: `gluco-hub/ha`.
- HA MQTT discovery topic: `homeassistant/sensor/gluco_hub_<client_id>_glucose/config`. Auto-creates `sensor.gluco_hub_<client_id>_glucose`.
- Since 2026.516.2: a sibling `sensor.<device>_trend` entity with `device_class: "enum"` and all Trend variants in `options`.
- Both entities have `has_entity_name: true` and `origin:` block.
  - Source: `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md`

### Clock View
- Served at Ingress path `/clock`. Responsive display classes: wall, phone, small, watch.
- Display modes: `?eink=1` (throttled SSE, stale label), `?lo=&hi=`, `?unit=`, `?dark=`.
- `/clock/state` → JSON snapshot; `/clock/events` → SSE stream.
- Cache-Control: no-store on all clock responses.
  - Source: `libre-glucose/DOCS.md`

### Glossary / Entity Attributes
Glucose sensor exposes: mgdl, mmol, trend (9 arrow variants), timestamp (ISO-8601 UTC), patient_id.
  - Source: `libre-glucose/DOCS.md`

## Configuration

Full config option reference in `libre-glucose/DOCS.md`. Notable:
- llu_region: one of AE/AP/AU/CA/DE/EU/EU2/FR/JP/US/LA/RU/CN — must match LibreView account region.
- llu_timezone: IANA TZ name, needed because LibreLink Up returns wall-clock time without offset.
- glucose_unit: mgdl or mmol (default mgdl). Affects discovery, not wire payload.
- log_level: info (default) or debug for troubleshooting.
  - Source: `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md`

## Troubleshooting

- `No MQTT service available` → install Mosquitto broker + configure MQTT integration.
- Sensor entity not appearing → set `log_level: debug`, check for `mqtt sink configured` + `discovery_enabled = true`.
- LLU login fails `[LLU003]` → wrong credentials, wrong region, or escaped special chars in password.
- Time-shifted values → set `llu_timezone` to patient's IANA TZ.
- Platform not in dropdown → only amd64/aarch64 in v1.
  - Source: `libre-glucose/DOCS.md`

## Version History

- **2026.516.2**: Trend sensor entity, has_entity_name, origin block.
- **2026.516.1**: http.enabled toggle (not exposed yet), liveness heartbeat, boilerplate cleanup (disclaimer edits, default client_id → ha, AppArmor s6 v3 fix, GitHub PVR-only security, `init: false` comment corrected, GitHub Pages).
- **2026.516.0**: glucose_unit option, pre-built multi-arch GHCR image, Taskfile.yml, CalVer release scheme, Renovate config, disclaimers broadened.
- **Initial (pre-2026.516.0)**: .gitignore, SECURITY.md, initial wrapper app, DLQ, AppArmor, CI/lint, icon/logo assets, translations.
  - Source: `libre-glucose/CHANGELOG.md`

## Known Limitations

- 32-bit platforms not supported (upstream limitation).
- Arrow icons not available via HA MQTT discovery — dashboard-level concern (template/mushroom card).
- app version mirrors upstream CalVer; not independently versioned.
- `http.enabled` not exposed in config.yaml yet (MQTT-only deployment).
  - Source: `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md`

## Security

- Scope split: upstream gluco-hub-rs concerns (polling, auth, MQTT logic) vs this repo concerns (manifest, AppArmor, run.sh, Dockerfile, CI).
- Supported versions: latest published release only.
- Disclosure timeline: acknowledge ≤5 working days, fix/mitigation ≤30 days.
- Not a medical device; maintainers accept no liability.
  - Source: `SECURITY.md`

## Maintenance

- Manual step after Renovate bumps upstream tag: add narrative entry to CHANGELOG.md.
- New config fields from upstream require deliberate addition to config.yaml, run.sh, both translations, and tests.
- Release cut via `task release` (commits + tags + pushes). CI builds + signs + publishes.
  - Source: `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md`

## Existing GSD Context (from .planning/ files)

- PROJECT.md: All 13 BRDG requirements defined, BRDG-01–09 confirmed complete in v1.0. BRDG-10/11/12/13 Pending.
- ROADMAP.md: v1.0 milestone marked SHIPPED. Backlog: ENHN-01–04.
- REQUIREMENTS.md: Same BRDG tracking with traceability matrix. ENHN-01–04 as v2 deferred.
- STATE.md: Phase 1 100% complete, milestone v1.0 completed 2026-06-07.
- Note: ENHN-02 (configurable polling) and ENHN-03 (health endpoint) appear already shipped per DOCS.md — backlog may need updating.

## Status

**0 conflicts.** No contradictions between ingested DOC documents or with existing `.planning/` files.
