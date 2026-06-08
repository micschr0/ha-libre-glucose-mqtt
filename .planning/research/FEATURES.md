# Feature Landscape

**Domain:** Home Assistant add-on for LibreLink Up glucose monitoring via MQTT
**Researched:** 2026-06-07
**Confidence:** HIGH (source code verified) / MEDIUM (community patterns) / LOW (API is unofficial, user expectation extrapolation)

---

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Single-patient glucose sensor | Baseline functionality — already delivered in v1.0 | Low | `sensor.gluco_hub_ha_glucose` via MQTT discovery |
| Glucose trend entity | Companion to value; HA dashboards show trend arrows | Low | Already delivered: `sensor.gluco_hub_ha_trend` with enum options |
| Per-reading timestamp attribute | Users build automations on time-since-last-reading | Low | Already exposed as entity attribute |
| LibreLink Up login (single account) | Required to function at all | Low | Already working; `llu_email` + `llu_password` |
| Region configuration | LibreLink Up has per-region API endpoints | Low | Already working; 13 regions supported |
| MQTT auto-discovery | Users expect entities to appear without YAML | Low | Already working; retained discovery config on ConnAck |
| Patient selection (single) | Accounts with multiple patients need disambiguation | Low | Already working; `llu_patient_id` selects one patient |
| Patient timezone | LibreLink Up returns wall-clock timestamps without offset | Low | Already working; `llu_timezone` per patient |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Multi-patient polling from single instance** | One LibreLink Up account can link multiple patients (family sharing). Poll all patients from one add-on, creating separate HA entities per patient. Removes need for multi-instance hacks. | **High** | Requires upstream gluco-hub-rs changes: multi-source fan-out or per-patient poll loop. MQTT discovery per patient needs unique `client_id` / `topic_prefix` per patient or a per-patient `unique_id` suffix. The current upstream architecture is one-source-per-instance. |
| **Patient list MQTT topic** | Lets users discover patient UUIDs without reading logs | Low | Already partially delivered: `_patients` topic publishes connection list |
| **Separate timezone per patient** | Multiple patients may be in different timezones; critical for accurate timestamps | Medium | Requires per-patient timezone config. LibreLink Up returns timestamps in patient's local wall-clock time without TZ offset. |
| **Combined dashboard view** | Single pane of glass for all household members' glucose; via Clock View or HA dashboard | Medium | Clock View already works for single patient. Multi-patient would need patient selector or side-by-side view. |
| **Per-patient alarm thresholds** | Different patients have different target ranges | Medium | Clock View already supports `?lo=70&hi=180` query params. Per-patient defaults would need upstream config. |
| **Separate LibreLink Up accounts per patient** | Some families use separate LibreLink Up accounts (not family sharing). Each add-on config section for a different account. | **High** | Requires multi-login support: either multiple `llu_email`/`llu_password` pairs in config, or the multi-instance add-on workaround. |
| **API resilience / retry per patient** | One patient's API failure shouldn't block others | Medium | Already handled per-poll in upstream; would need per-patient isolation for multi-patient. |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Multi-instance add-on (copied slug)** | HA Supervisor does not support running the same slug twice. Users would need to copy the addon folder, change the slug, and maintain parallel installs. Fragile, unsupported, and confuses backups/updates. | Support multi-patient within one add-on instance (upstream gluco-hub-rs multi-source). |
| **Combined/averaged glucose across patients** | Medically meaningless and dangerous — glucose values are per-patient physiological measurements. Averaging them would mask individual hypo/hyper events. | Always publish per-patient sensors. Let users create template sensors if they want aggregates. |
| **Automatic patient detection without confirmation** | Privacy risk — LibreLink Up connections list exposes patient names. Auto-creating sensors for all linked patients without explicit opt-in could surprise users sharing an account. | Require explicit patient configuration (list of patient IDs to monitor), or default to single-patient with an opt-in "all patients" toggle. |
| **Combined LibreLink Up login from multiple accounts** | LibreLink Up API is unofficial. Sharing credentials across accounts amplifies ToS violation risk. One account with family sharing is the intended use case. | If separate accounts are needed, document that users must run separate add-on instances (with different slugs via copy), or wait for upstream multi-login support. |

## Feature Dependencies

```
Multi-patient polling (separate sensors per patient)
├── Upstream gluco-hub-rs multi-source or per-patient poll loop
│   └── Current architecture: one LluSource per gluco-hub instance
│       └── CHANGE NEEDED: either multiple LluSource instances, or a "fan-out" poller
├── MQTT discovery per patient
│   └── Requires unique client_id or unique_id suffix per patient
│       └── Already possible: different `client_id` per patient → different discovery topics
├── Per-patient timezone
│   └── Already supported per LluSource; needs per-patient config exposure
├── Per-patient unit preference
│   └── LibreLink Up always returns mg/dL; unit conversion is client-side
│       └── Already supported per instance; needs per-patient config exposure
└── Dashboard aware of multiple patients
    └── Clock View needs patient selector (or separate page per patient)

Separate LibreLink Up accounts (independent logins)
├── Upstream gluco-hub-rs multi-credential support
│   └── Not in current architecture; would need LluSource per credential
├── OR multi-instance add-on (different slugs)
│   └── HA Supervisor limitation: no native multi-instance
│       └── Workaround: template/copy addon with different slug
│           └── Maintenance burden: user must update both copies
└── RECOMMENDATION: Defer to v2+. Multi-account per LibreLink Up family sharing covers 90%+ use case.
```

## MVP Recommendation

For v1.1 (ENHN-01: multi-account support):

### Phase 1: Multi-patient within one account (Recommended MVP)

Prioritize:
1. **Poll all patients from a single LibreLink Up account** — family sharing is the dominant use case
2. **Separate HA sensor entities per patient** — `sensor.gluco_hub_ha_glucose_alice`, `sensor.gluco_hub_ha_glucose_bob`
3. **Per-patient timezone** — critical for correct timestamps
4. **Opt-in patient selection** — explicit config of which patients to monitor (privacy/safety)
5. **`_patients` MQTT topic already exists** — leverage for patient discovery UI

Defer:
- Separate LibreLink Up accounts (different credentials): requires multi-instance or upstream multi-login. Address with documentation workaround (copy addon with different slug) for v1.1, proper solution in v2+.
- Combined dashboard view: HA's native Lovelace already handles multiple sensors on one dashboard. Clock View multi-patient is a v2 enhancement.

### Phase 2: API Resilience (ENHN-04)

Prioritize:
1. **Per-patient error isolation** — one patient's API failure doesn't block others
2. **Token sharing across patients** — single login token used for all patients (already cached)
3. **Rate limiting awareness** — LibreLink Up is unofficial; poll all patients within one cycle, not sequentially adding delay

## HA Add-on Ecosystem Patterns

### Pattern: Singleton add-on (current)
One add-on slug, one configuration, one set of entities. Works for single-patient, single-account. **HA Supervisor constraint: one slug = one container. Cannot run same slug twice.**

### Pattern: Variant slugs (Frigate approach)
Frigate publishes `frigate`, `frigate_fa`, `frigate_beta`, `frigate_oldcpu` as separate add-ons with different slugs. Each is independently installed, configured, and updated. **Good for: pre-defined variants (stable vs beta, full-access vs standard). Bad for: N arbitrary instances** (you'd need N add-on folders).

### Pattern: Internal multi-tenancy (Mosquitto approach)
Mosquitto add-on supports multiple user accounts internally via its own config. One add-on instance, many "logical" accounts. **Best fit for our use case: one add-on, multiple patients.** Upstream gluco-hub-rs needs to support polling multiple patients from one source config.

### Pattern: Integration subentries (HA Core MQTT)
The HA MQTT integration supports subentries — you can add multiple MQTT device configs under one integration. **Not applicable to add-ons directly**, but the MQTT discovery unique_id mechanism achieves the same: different `unique_id` → different entity.

### What users actually do today for "multiple instances"
Community reports indicate users:
1. Copy the addon folder, change the slug in `config.yaml`, install as a "local" add-on
2. Accept that updates require manual copy-and-replace for each instance
3. Some add-on developers provide multi-instance via template mechanism (rare)

**For Libre Glucose: multi-patient within one instance is the right answer.** Avoids the HA Supervisor multi-instance limitation entirely.

## LibreLink Up API: Multi-Patient Findings

### API structure (verified from gluco-hub-rs source code)

```
POST /llu/auth/login           → returns auth ticket + token
GET  /llu/connections           → returns list of Connection objects
GET  /llu/connections/:id/graph → returns 24h graph data for one patient
```

**Key insight:** One LibreLink Up login session grants access to ALL linked patients. The `/llu/connections` endpoint returns a list. Each connection has:
- `patientId` (UUID)
- `firstName`, `lastName`
- `glucoseMeasurement` (live reading, 1-min fresh)

The graph endpoint is per-patient. The live reading on the connection object is 1-minute-fresh (vs 5-minute raster in graph data).

### Family sharing model
LibreLink Up's "LibreView" family sharing: one caregiver creates a LibreView account, then patients (or their guardians) share their sensor data with that account. The caregiver sees all linked patients in the LibreLinkUp app. The API mirrors this: all patient connections visible under one login.

### Multiple separate accounts
If two people have completely separate LibreLink Up accounts (not family-shared), there is NO single-login way to access both. Each needs its own credentials. This is the "separate accounts" use case — lower priority, as family sharing covers the majority of multi-patient households.

### API rate limiting (inferred, LOW confidence)
The LibreLink Up API is unofficial and undocumented. Observed behavior from the gluco-hub-rs codebase:
- Readings update every ~60 seconds (sensor uplink interval)
- Graph endpoint returns ~24h of data at ~5-minute raster
- Token lifetime appears to be ~1 hour (based on `DEFAULT_EXPIRY_SKEW_SECS: 60`)
- No explicit rate limiting observed, but polling faster than 30s is wasteful
- Multiple patients polled from one login: each patient requires a separate `/llu/connections/:id/graph` call. At 2-3 patients, this is 2-3 additional HTTP calls per poll cycle — well within reasonable limits for a 60s poll interval.

## User Expectations for Multi-Patient Glucose Monitoring

### From the diabetes community and Nightscout patterns

| Expectation | Priority | Rationale |
|-------------|----------|-----------|
| One sensor entity per patient | **Critical** | Users build automations, dashboards, and alerts per patient. Combined/averaged values are medically meaningless. |
| Patient name in entity | **High** | Users need to distinguish "Alice's glucose" from "Bob's glucose" at a glance. HA's `device` name + entity name handles this if `unique_id` differs per patient. |
| Separate trend per patient | **High** | Trend arrows are per-patient physiological data. |
| Per-patient timezone | **High** | Timestamps must be correct for each patient. Already handled upstream per `LluSource`. |
| Same LibreLink Up login | **High** | Family sharing is the standard way LibreLinkUp/LibreView handles multi-patient. Users expect this to work. |
| Separate alert thresholds | **Medium** | Target ranges differ by patient (child vs adult, T1 vs T2). Clock View supports `?lo=70&hi=180` but defaults are instance-wide. |
| Combined dashboard | **Medium** | "See all my kids' glucose at once." HA Lovelace handles this natively with multiple sensor cards. Clock View multi-patient is a separate feature. |
| Separate LibreLink Up accounts | **Low** | Edge case where family members use completely separate accounts. Workaround: copy addon with different slug (documented). |
| Historical data per patient | **Low** | LibreLink Up graph endpoint provides 24h. HA's recorder stores entity history. No additional work needed. |

### Nightscout comparison

Nightscout is the de-facto standard for DIY CGM monitoring. It handles multi-patient by running separate Nightscout instances (separate URLs, separate databases) per patient. Each instance has its own API secret and upload endpoint. Caregivers monitor multiple patients by opening multiple browser tabs or using a dashboard that embeds multiple Nightscout iframes.

This validates the "separate entities per patient" approach. Nightscout does NOT combine patients into one view — it keeps them separate for medical safety.

## Sources

- **gluco-hub-rs source code** (HIGH confidence): `gluco-hub/src/sources/llu/wire.rs` (Connection struct, API endpoints), `gluco-hub/src/sources/llu/source.rs` (LluSource, ConnectionSelection, poll loop). The `/llu/connections` endpoint returns multiple patients. Graph endpoint is per-patient.
- **Home Assistant Developer Docs** (HIGH confidence): `developers.home-assistant.io/docs/apps/configuration/` — add-on config schema, no multi-instance support documented
- **MQTT Discovery spec** (HIGH confidence): `home-assistant.io/integrations/mqtt/#mqtt-discovery` — unique_id prevents duplicates, object_id in topic, device context for grouping
- **Frigate add-on repo** (MEDIUM confidence): `github.com/blakeblackshear/frigate-hass-addons` — variant slug pattern (frigate, frigate_fa, frigate_beta)
- **Nightscout cgm-remote-monitor** (MEDIUM confidence): `github.com/nightscout/cgm-remote-monitor` — separate instances per patient is the standard in CGM monitoring
- **Community patterns** (LOW confidence): HA community discussions about multi-instance add-ons — copy + rename slug workaround is fragile but documented
- **LibreLink Up API behavior** (MEDIUM confidence): Inferred from source code; API is unofficial and could change without notice
