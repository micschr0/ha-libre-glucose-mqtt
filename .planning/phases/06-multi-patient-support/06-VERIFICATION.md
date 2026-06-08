---
status: blocked
phase: 6
name: Multi-Patient Support
verified: 2026-06-07
---

# Phase 6 Verification: Multi-Patient Support

## Status: BLOCKED

Phase 6 cannot be verified through automated testing — all implementation depends on upstream gluco-hub-rs multi-source architecture.

## Design Completeness

| Deliverable | Status |
|-------------|--------|
| Upstream architecture spec | ✅ 06-UPSTREAM-SPEC.md |
| Add-on config schema design | ✅ 06-ADDON-DESIGN.md |
| run.sh TOML generation design | ✅ 06-ADDON-DESIGN.md |
| MQTT naming & collision prevention | ✅ 06-ADDON-DESIGN.md |
| Token isolation design | ✅ 06-UPSTREAM-SPEC.md |
| Backward compat plan | ✅ 06-UPSTREAM-SPEC.md |

## Success Criteria (all blocked by upstream)

- [ ] 1. One add-on instance monitors multiple accounts/patients → needs upstream
- [ ] 2. Per-patient MQTT entities with distinct unique_id → needs upstream
- [ ] 3. HA auto-discovers per-patient sensors → needs upstream
- [ ] 4. One account's failure doesn't block others → needs upstream
- [ ] 5. Existing single-account configs work identically → needs upstream

## Human Verification

When upstream multi-source support lands:
1. Verify multi-account config panel appears in HA Supervisor UI
2. Verify each patient gets separate sensor entities in HA
3. Kill one account's credentials → verify other accounts still poll
4. Verify existing single-account config still works after upgrade
