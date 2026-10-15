# Resume ALONA / Rider integration

Projects: Rider `C:\Users\user\rider`; ALONA `C:\Users\user\alona-ecommerce-integration`.
Current phase: 4. Objective: shared ALONA API integration with safe disk checkpoints.
Last successful checkpoint: 2026-10-14T20:25:26.828Z.

## NEXT CODEX SESSION

1. Verify both directories; read applicable AGENTS.md, this file, CHECKPOINT.md, PROGRESS.md, then existing project memory.
2. Check Git branch/status in both projects. Rider is currently not Git-tracked; compare recorded file hashes instead.
3. Run `node scripts/integration_checkpoint.cjs --verify` from Rider. Inspect only changed/incomplete files; trust verified source over notes.
4. Treat commands listed as running/interrupted as UNKNOWN. Rerun only affected focused checks; never repeat migrations or destructive actions automatically.
5. Next exact task: Run registration tests and existing ALONA onboarding/address/coverage checks
6. Save a checkpoint before each phase, meaningful edit batch, risky edit, long test/build, and after each phase. Use --update with a JSON update file; complete content is flushed to a same-directory temporary file, atomically replaced and verified. Do not edit checkpoint documents manually.

Dependencies: existing ALONA Sanctum, partner registration/address/coverage contracts, Rider approval and parcel authorization. No extra backend/database.
Relevant files: use the scoped lists in CHECKPOINT.md and ../ARCHITECTURE.md.
Verification commands: `node --test scripts/integration_checkpoint.test.cjs`; `flutter test --no-pub <affected-tests>`; `flutter analyze --no-pub --no-fatal-infos <affected-files>`; ALONA `php vendor/phpunit/phpunit/phpunit --do-not-cache-result <affected-tests>` with DB_CONNECTION=sqlite, DB_DATABASE=:memory:, DB_URL empty. Never test against development/production records.

Blockers / decisions:

- Rider is not Git-tracked; all Rider work exists only locally
- Device/production/full workflow unverified
- Profit calculation and rider payout storage unspecified; no monetary values will be invented
- Registration still sends the legacy contract
- Four pre-existing proof-radio deprecation notices

Authorization: continue Phases 4-10 where safe per the latest user request. Phase 3 is completed; do not reimplement it. Commits require explicit permission. No permission to invent rider earnings or payout rules.
Limitations: no automatic Codex launch after reboot, unsaved edit/process recovery, protection against disk corruption/deletion, or off-device backup. Existing valid files are preserved if atomic replacement fails.
