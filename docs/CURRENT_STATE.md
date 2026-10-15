# Current state

- **Verified 2026-10-15:** Phases 1-9 backend integration implemented. Phase 7 adds
  ALONA seller shipments and separate PHP 50 seller charge / PHP 10 Logistics /
  PHP 40 rider earning, full manual collection/payout, unique package accrual after
  all noncancelled parcels have rider proofs. Rider UI and Delivery History preserved.
- New checkout creates one shipment per seller/order and zero buyer shipping including
  express; method metadata/labels retained. Product vouchers remain separate. Historical
  totals/memberships are not backfilled. Migration file created, not applied outside tests.
- Current Phase 7 tests: 17 focused finance tests / 128 assertions PASS; final affected
  Logistics suite 96 tests / 581 assertions PASS (includes finance). All 28 scoped PHP
  syntax checks passed. Deployment-engine concurrency/live acceptance remains pending.
- Prior Phase 10 automated checks passed: 60 Rider tests, 119 relevant in-memory Laravel
  tests, 7 recovery/safety tests, clean Flutter analysis and release JavaScript web
  compile. iOS permission XML has one camera/photo key at the root.
- **NEEDS VERIFICATION:** physical device/camera, real email verification/approval,
  production API reachability/CORS and complete real-world workflow. Configure
  PHP upload limits: current 2M/file, 8M/request are below application limits.
- Notifications use existing unread messages/active tasks in-app. Optional WASM
  builds remain unsupported by the current secure-storage web dependency.
- Read docs/integration/RESUME.md, CHECKPOINT.md and PROGRESS.md before resuming.
  Both projects are Git-tracked; preserve their recorded branches/local changes.
- Final scoped review completed 2026-10-15: no actionable defects or credential-pattern
  matches in 51 changed/untracked files; both Git whitespace checks passed. Exact
  proposed commit boundaries, financial evidence/design and manual acceptance matrix
  are in docs/integration/FINAL_REVIEW.md. Subsequent Phase 7 code/test evidence is
  in current checkpoints and ALONA docs/DELIVERY_FINANCE.md; earlier commit lists need
  the new backend files included before any later explicitly authorized commit.
- No automatic commit, push, production migration, dependency installation or production-data
  operation was performed. Existing ALONA backend/database and UI styling are reused.
