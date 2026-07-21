<!-- doc-review: 2026-07-21 -->

# Libre Glucose MQTT Bridge — Documentation

Install the add-on, set your LibreLink Up email, password, and region, and watch the **Glucose** sensor appear under **Settings → Devices & Services → MQTT** within minutes.

## Quick start

1. Install the **Mosquitto broker** add-on and configure the **MQTT** integration (see [Prerequisites](#prerequisites)).
2. Add this repository to the add-on store and install **Libre Glucose MQTT Bridge** (see [Install](#install)).
3. Set `llu_email`, `llu_password`, and `llu_region` in the **Configuration** tab.
4. Click **Start** and wait ~30 seconds for the first reading.
5. Find the **Glucose** sensor under **Settings → Devices & Services → MQTT → Gluco Hub**.

## Prerequisites

You need three things before you click **Install**:

- **Home Assistant OS or Supervised.** Container installations cannot run add-ons.
- **Mosquitto broker add-on** installed and started, and the **MQTT integration** configured. The add-on refuses to start without an MQTT service.
- **A LibreLink Up account** with at least one active connection — typically a family-share invitation from a Libre 2 or Libre 3 sensor wearer.

> **Don't disable the Mosquitto broker after install.** This add-on depends on it and will refuse to start.

If Mosquitto is not yet installed: open **Settings → Add-ons → Add-on Store**, search for *Mosquitto broker*, install it, then add the **MQTT** integration under **Settings → Devices & Services → Add Integration → MQTT**.

## Install

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add the repository URL:

   ```
   https://github.com/micschr0/ha-libre-glucose-mqtt
   ```

4. Refresh the store; **Libre Glucose MQTT Bridge** appears in a new section.
5. Click it → **Install**.

> **Don't install on 32-bit ARM or i386.** Only `amd64` and `aarch64` are built and supported. If your platform is not in the install dropdown, this add-on won't run on your hardware.

## Configure

Three fields are required. Fill them, leave everything else on defaults, then click **Start**.

| Field | Example | Notes |
|---|---|---|
| `llu_email` | `anna@example.com` | The account that holds the family-share invitation. |
| `llu_password` | `correct-horse-battery-staple` | Stored only in the add-on options; never written to MQTT or logs. |
| `llu_region` | `EU` | Must match your **LibreView account region** — not your physical country. See below. |

Valid regions: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `US`, `LA`, `RU`, `CN`.

> **Don't set `llu_region` to your physical country.** Use the region of your LibreView account — they often differ. If unsure, open the LibreView app; the region is shown under **Account settings**.

Two optional fields worth setting now:

- **`llu_timezone`** — IANA timezone of the sensor wearer, e.g. `Europe/Berlin`. Without this, timestamps appear shifted by your UTC offset.
- **`poll_interval_secs`** — leave at `60` unless you have a reason. LibreLink Up updates every ~60 s; lower values waste API quota.

> **Don't set `poll_interval_secs` below 30.** LibreLink Up updates roughly every 60 seconds; faster polling wastes your API quota and can trigger rate limits.

For every other option (device name, glucose unit, MQTT topic prefix, client ID, multi-account, log level) see the **Configuration** tab in the HA UI.

## Verify

After **Start**, the add-on takes about 30 seconds to publish the first reading. Look for:

- **Settings → Devices & Services → MQTT → Gluco Hub → Glucose** — a new sensor with the current mg/dL reading as the state.
- The sensor entity ID is **`sensor.gluco_hub_ha_glucose`** by default. If you changed `client_id`, replace `ha` with your value.

If the sensor does not appear, enable debug logging and check for key messages (see [Sensor never appears](#sensor-never-appears) below).

## Common failures

| Symptom | Likely fix |
|---|---|
| Add-on refuses to start | Install Mosquitto broker + MQTT integration |
| `[LLU003]` login error | Wrong credentials, region, or password escaping |
| Sensor never appears | Mosquitto running? Check MQTT discovery messages |
| Values are time-shifted | Set `llu_timezone` to patient's IANA timezone |

### Won't start — "No MQTT service available"

Install the Mosquitto broker add-on and configure the MQTT integration. Then restart this add-on.

If your platform is not in the install dropdown: only `amd64` and `aarch64` are supported. 32-bit ARM (`armv7`, `armhf`) and `i386` are not.

### Login fails — `[LLU003]`

Wrong credentials, wrong region, or the password was escaped incorrectly by the HA UI. The region must match your LibreView account region, not your physical country.

### Sensor never appears

1. Confirm Mosquitto is running.
2. Set `log_level: debug` and look for `mqtt sink configured` and `discovery_enabled = true` in the log.
3. Subscribe a debug MQTT client to `homeassistant/sensor/+/config`. The discovery message should arrive within ~10 seconds.

### Sensor values are time-shifted

Set `llu_timezone` to the patient's IANA timezone (`Europe/Berlin`, `America/New_York`). LibreLink Up timestamps are local wall-clock with no UTC offset.

> **Don't paste your password into the troubleshooting log.** The add-on never logs it; if you see it in a trace, that is a bug — open an issue.

## Where to go next

Once the **Glucose** sensor is live, you may want:

- **Display live glucose on a wall panel or e-ink screen** → [Clock View](https://micschr0.github.io/ha-libre-glucose-mqtt/clock-view.html)
- **Poll multiple LibreLink Up accounts** → [Multi-account setup](https://micschr0.github.io/ha-libre-glucose-mqtt/multi-account.html)
- **Read glucose programmatically** → [HTTP Status API](https://micschr0.github.io/ha-libre-glucose-mqtt/status-api.html)
- **See every option in detail** → [Configuration reference](https://micschr0.github.io/ha-libre-glucose-mqtt/configuration.html)

These pages are part of the [project documentation site](https://micschr0.github.io/ha-libre-glucose-mqtt/). The **Clock View** and **HTTP Status API** are served by the upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs) binary — this add-on only wires HA Ingress to them.

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.
>
> LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott. AGPL-3.0-or-later.
