# Security Policy

## Scope

This repository ships the Home Assistant **app** wrapper (formerly
known as an add-on) around the upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs)
Rust binary. Two repositories are relevant when reporting security
issues, and you should pick the right one:

| Symptom | Report here |
|---|---|
| Glucose-data parsing / LibreLink-Up authentication / MQTT publish logic / Nightscout / DLQ / HTTP API | [`gluco-hub-rs` SECURITY.md](https://github.com/micschr0/gluco-hub-rs/blob/main/SECURITY.md) — these are upstream concerns |
| HA Supervisor wrapper: app manifest (`config.yaml`), AppArmor profile (`apparmor.txt`), `run.sh` entrypoint, Dockerfile, CI workflows | This repo (see below) |

If you are unsure, file here — we'll route upstream as needed.

## Reporting a vulnerability

**Do not open a public GitHub issue for security-sensitive reports.**

Use GitHub's [private vulnerability reporting](https://github.com/micschr0/ha-libre-glucose-mqtt/security/advisories/new) — the discussion stays auditable in-platform and triggers a GitHub Security Advisory on confirmation.

Please include:

- A description of the issue and its impact.
- Reproduction steps, including any `config.yaml` options or HA
  Supervisor versions involved.
- Whether the issue is exploitable from outside the Mosquitto add-on's
  internal network (`hassio` bridge) or only from co-located add-ons.

## Disclosure

We aim to acknowledge reports within 5 working days and to ship a fix
or a documented mitigation within 30 days for confirmed issues.
Coordinated disclosure with the upstream `gluco-hub-rs` maintainers is
the default for any issue that touches polling or wire-format logic.

## Not a medical device, not affiliated with Abbott

This app and its upstream are research / self-hosting tools, **not
medical devices**. They are not for medical decisions, therapy,
dosing, or diagnosis. They poll Abbott's LibreLink Up API without any
partnership; **use may violate Abbott's LibreLink Up Terms of
Service**, and the maintainers accept no liability for account
suspension or any other consequence. Use at your own risk.

Issues that report "the glucose number is wrong" without a separate
security implication should be filed as bugs (issue tracker), not as
security advisories. ToS or contractual concerns with Abbott are out
of scope for this repository — those are between the user and Abbott.

## Supported versions

We ship security fixes for the latest published app release only. The
app version mirrors the bundled upstream gluco-hub CalVer tag exactly,
so a fix shipped as `app v2026.M.0` rides on `gluco-hub v2026.M.0`.
