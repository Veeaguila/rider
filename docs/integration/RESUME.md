# Resume ALONA / Rider integration

Projects: Rider `C:\Users\user\rider`; ALONA `C:\Users\user\alona-ecommerce-integration`.
Current phase: 10. Objective: shared ALONA API integration with safe disk checkpoints.
Last successful checkpoint: 2026-10-16T07:32:08.832Z.

## NEXT CODEX SESSION

1. Verify both directories; read applicable AGENTS.md, this file, CHECKPOINT.md, PROGRESS.md, then existing project memory.
2. Check Git branch/status in both projects. Rider is Git-tracked; preserve existing commits and local changes.
3. Run `node scripts/integration_checkpoint.cjs --verify` from Rider. Inspect only changed/incomplete files; trust verified source over notes.
4. Treat commands listed as running/interrupted as UNKNOWN. Rerun only affected focused checks; never repeat migrations or destructive actions automatically.
5. Next exact task: Rider source/UI publication verified. The accompanying documentation commit records this receipt; use Git history/remote refs for its final tip. Resume live integration by obtaining the working ALONA website/API URL and existing database identity, then verify the serving project/schema read-only before configuration or migration changes.
6. Save a checkpoint before each phase, meaningful edit batch, risky edit, long test/build, and after each phase. Use --update with a JSON update file; complete content is flushed to a same-directory temporary file, atomically replaced and verified. Use --run for test/build commands; running and confirmed outcomes are saved automatically. If bundle IDs disagree, use --recover to verify and restore the complete previous bundle while archiving interrupted notes. Inspect RECOVERY_NOTES.md and changed source before continuing. Do not edit checkpoint documents manually.

Dependencies: existing ALONA Sanctum, partner registration/address/coverage contracts, Rider approval and parcel authorization. No extra backend/database.
Relevant files: use the scoped lists in CHECKPOINT.md and ../ARCHITECTURE.md.
Verification commands: `node --test scripts/integration_checkpoint.test.cjs`; `flutter test --no-pub <affected-tests>`; `flutter analyze --no-pub --no-fatal-infos <affected-files>`; ALONA `php vendor/phpunit/phpunit/phpunit --do-not-cache-result <affected-tests>` with DB_CONNECTION=sqlite, DB_DATABASE=:memory:, DB_URL empty. Use the --run alona wrapper for PHPUnit: it refuses cached application configuration and forces an in-memory database. Never clear shared config automatically or test against development/production records.

Blockers / decisions:

- BLOCKED: identify actual populated ALONA MySQL schema/configuration. Confirmed project .env selects empty local SQLite; MySQL80 localhost:3306/InnoDB exists, Workbench has no schema saved; OS denies data-directory listing. Need actual schema name or original config source, never passwords in chat.
- Pre-existing chronological fresh MySQL migration ordering fails: order_items FK precedes product_variants. Existing-schema Phase 7 rehearsal passed with explicit disposable dependency ordering; no application migration changed.
- Actual populated database never connected or modified. No application connection/configuration switched. User prohibits further database creation until approval.
- Production readiness remains unverified; passing compile uses placeholder API URL. Actual native/device/email/live/admin tests pending.
- New rider_notifications migration prepared but not applied to actual DB; requires approved matching-engine rehearsal and compatible backend/schema rollout. Photo/profile tests cover memory DB only; MySQL locking races still pending.
- Rider feed remains best-effort after-commit without durable replay/background push; crash after commit may lose a Rider notice. New Seller delivery notice is atomic inside completion transaction.
- Android debug build blocked by missing SDK; iOS requires macOS/Xcode; native scan/camera/lifecycle and live four-role proof access pending. Browser scanning not implemented; manual reference/photo selection retained.
- Legacy parcels without verified item/product/Seller links are not guessed or notified and cannot expose Seller proof. Historical completed statuses remain unchanged.
- New parcel proof/notice concurrency scenarios require an approved matching-engine copy; SQLite-memory tests establish contracts/rollback, not InnoDB locking.

Authorization: continue Phases 4-10 where safe per the latest user request. Phase 3 is completed; do not reimplement it. Commits require explicit permission. No permission to invent rider earnings or payout rules.
Limitations: no automatic Codex launch after reboot, unsaved edit/process recovery, protection against disk corruption/deletion, or off-device backup. Existing valid files are preserved if atomic replacement fails.
