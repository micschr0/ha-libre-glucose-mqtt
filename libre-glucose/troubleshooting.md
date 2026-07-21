<!-- doc-review: 2026-07-21 -->

# Troubleshooting

Quick-lookup reference for common issues. Each section gives the fix first, then diagnostics.

## Add-on refuses to start

**Fix:** Install the **Mosquitto broker** add-on and configure the MQTT integration (Settings → Devices & Services → Add Integration → MQTT). Then restart this add-on.

The add-on exits with `No MQTT service available` when no MQTT service is registered with the Supervisor — the Mosquitto broker add-on is missing or the MQTT integration is not configured.

## Sensor never appears

**Fix:** Confirm Mosquitto is running and restart the add-on.

**Diagnose:**
1. Set `log_level: debug` and look for `mqtt sink configured` and `discovery_enabled = true` in the log.
2. Use MQTT's *Listen to topic* feature: subscribe to `homeassistant/sensor/+/config`. The discovery message should arrive within ~10 seconds of starting.

## LibreLink Up login fails

**Fix:** Verify your LibreLink Up credentials and region. The region must match your LibreView account, not your physical location.

Error code `[LLU003]` means wrong credentials, wrong region, or the password was escaped incorrectly by the HA UI.

## Sensor values are time-shifted

**Fix:** Set `llu_timezone` to the patient's IANA timezone (e.g. `Europe/Berlin`).

LibreLink Up timestamps are in local wall-clock time with no UTC offset. Without the correct timezone the add-on interprets them as UTC.

## Platform not in install dropdown

**Fix:** V1 supports `amd64` and `aarch64`. 32-bit ARM (`armv7`, `armhf`) and `i386` are not supported — follow [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs) for status.

## Architecture

<details>
<summary>How the pieces fit together</summary>

```text
LibreLink Up API
       │ HTTPS
       ▼
┌──────────────────────────────────────┐
│ libre-glucose app                    │
│  ┌────────────────────────────────┐  │
│  │ run.sh (bashio)                │  │
│  │  • read /data/options.json     │  │
│  │  • bashio::services mqtt       │  │
│  │  • export GLUCO_HUB__*         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ /usr/local/bin/gluco-hub run   │  │
│  │  LLU-Source → MQTT-Sink (+DLQ) │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
       │ MQTT (plaintext, internal)
       ▼
   Mosquitto app
       │
       ▼
   Home Assistant entities
```

This add-on is a thin Bash wrapper around [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs). No polling or MQTT logic lives here — only the HA manifest, `run.sh`, and this documentation. This add-on only wires HA Ingress to it.

</details>

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.
