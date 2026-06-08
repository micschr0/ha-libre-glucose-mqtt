# Upstream Tracking: gluco-hub-rs API Resilience

**Phase:** 5 | **Written:** 2026-06-07

## 1. HTTP 429 Rate-Limit Handling (ENH-05)

**File:** `src/source.rs`
**Change:** Parse `Retry-After` header on HTTP 429. Sleep + retry up to 3x. Token cache must survive rate-limit errors.

## 2. Critical Field Optionality (ENH-07)

**File:** `src/wire.rs`
**Change:** Make `ValueInMgPerDl`, `TrendArrow`, `Timestamp` fields `Option<T>`. Missing fields → warning log, no crash. Empty glucose → skip reading. Empty trend → `NotComputable`.

## 3. Schema Fingerprint (ENH-08)

**File:** `src/main.rs`
**Change:** Log sorted, comma-separated list of LLU JSON field names at startup: `ValueInMgPerDl, ValueInMmolPerL, TrendArrow, Timestamp, PatientId`.
