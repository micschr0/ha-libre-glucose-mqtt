# Code Review — Phase 1

## Files Reviewed
- libre-glucose/run.sh
- libre-glucose/config.yaml
- libre-glucose/Dockerfile
- libre-glucose/build.yaml
- libre-glucose/translations/en.yaml
- libre-glucose/translations/de.yaml

## Findings

### severity: info
- **libre-glucose/run.sh**: 76 — `GLUCO_HUB__SINK__MQTT__TLS` is hardcoded to `"false"`. There is no app option to enable TLS for the MQTT connection to the Mosquitto broker. If the user runs a TLS-enabled Mosquitto (or a future Supervisor MQTT service provides TLS), this container cannot use it without a code change. Consider making this configurable via an app option.

- **libre-glucose/run.sh**: 22 — `MQTT_PORT` is captured as a raw string from `bashio::services` and exported as-is. There is no validation that it is a valid numeric port (1–65535). An upstream misconfiguration or future Supervisor change that returns a non-numeric value would flow through silently and fail confusingly at the TCP-connect level.

- **libre-glucose/run.sh**: 43-48 — Only `llu_email` and `llu_password` are validated as required at the bash level. Options like `llu_region`, `llu_timezone`, and `glucose_unit` are enforced only by the config.yaml schema (which the Supervisor validates at the UI level), not by the entrypoint script. If someone edits `/data/options.json` by hand or the Supervisor skips schema validation, invalid values pass through uncaught.

- **libre-glucose/Dockerfile**: 68 — The `HEALTHCHECK CMD` appends `|| exit 1` outside the inner `bash -c`. Although functionally correct (any non-zero exit is unhealthy regardless), the chained `|| exit 1` is redundant and adds a confusing indirection. The HEALTHCHECK shell form already treats any non-zero exit as unhealthy — `bash -c '</dev/tcp/127.0.0.1/8080'` alone would suffice.

- **libre-glucose/config.yaml**: 109 — `llu_timezone` is schema-typed as `"str"` with no validation against the IANA timezone database. An invalid or mistyped timezone (e.g. `"Europe/Berln"`) would pass Supervisor validation and only fail at the Rust binary's first timestamp conversion.

- **libre-glucose/config.yaml**: 113 — `topic_prefix` is schema-typed as `"str"` with no pattern or length constraint. The Rust binary may silently truncate or reject values that are too long or contain forbidden characters. Consider adding a `match()` constraint matching what gluco-hub-rs accepts (topic segments have MQTT-level length limits).

- **libre-glucose/translations/de.yaml**: 65 — "Default" is used as an English loanword in an otherwise German description. While common in German tech writing, the en.yaml uses "Default" on line 46 as well; keeping the English term consistent across both files is acceptable, but for full localization consistency the de.yaml could use "Standard" or "Voreinstellung".

## Summary
- Total findings: 7
- Critical: 0
- Warning: 0
- Info: 7

No bugs or security vulnerabilities were found. All issues are minor code-quality and hardening observations. The codebase is well-structured with clear comments, consistent env-var naming, proper signal handling via `exec`, and thorough schema definitions in config.yaml.
