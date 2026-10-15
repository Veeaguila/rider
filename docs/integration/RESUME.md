# Resume ALONA / Rider integration

Projects: Rider `C:\Users\user\rider`; ALONA `C:\Users\user\alona-ecommerce-integration`.
Current phase: 10. Objective: shared ALONA API integration with safe disk checkpoints.
Last successful checkpoint: 2026-10-15T10:28:21.185Z.

## NEXT CODEX SESSION

1. Verify both directories; read applicable AGENTS.md, this file, CHECKPOINT.md, PROGRESS.md, then existing project memory.
2. Check Git branch/status in both projects. Rider is Git-tracked; preserve existing commits and local changes.
3. Run `node scripts/integration_checkpoint.cjs --verify` from Rider. Inspect only changed/incomplete files; trust verified source over notes.
4. Treat commands listed as running/interrupted as UNKNOWN. Rerun only affected focused checks; never repeat migrations or destructive actions automatically.
5. Next exact task: Verify Rider master against origin/master and check working-tree status; if clean and matching, GitHub save including final checkpoint documentation is complete and must not be repeated. Otherwise finish publishing only the reviewed checkpoint docs under the existing user authorization. ALONA backend remains local/separate; remaining integration work is operator/manual deployment and acceptance, with no automatic production migrations or data changes.
6. Save a checkpoint before each phase, meaningful edit batch, risky edit, long test/build, and after each phase. Use --update with a JSON update file; complete content is flushed to a same-directory temporary file, atomically replaced and verified. Use --run for test/build commands; running and confirmed outcomes are saved automatically. If bundle IDs disagree, use --recover to verify and restore the complete previous bundle while archiving interrupted notes. Inspect RECOVERY_NOTES.md and changed source before continuing. Do not edit checkpoint documents manually.

Dependencies: existing ALONA Sanctum, partner registration/address/coverage contracts, Rider approval and parcel authorization. No extra backend/database.
Relevant files: use the scoped lists in CHECKPOINT.md and ../ARCHITECTURE.md.
Verification commands: `node --test scripts/integration_checkpoint.test.cjs`; `flutter test --no-pub <affected-tests>`; `flutter analyze --no-pub --no-fatal-infos <affected-files>`; ALONA `php vendor/phpunit/phpunit/phpunit --do-not-cache-result <affected-tests>` with DB_CONNECTION=sqlite, DB_DATABASE=:memory:, DB_URL empty. Use the --run alona wrapper for PHPUnit: it refuses cached application configuration and forces an in-memory database. Never clear shared config automatically or test against development/production records.

Blockers / decisions:

- Phase 7 implementation/design approval gates cleared; backend implemented and tested, migration not deployed.
- No split shipments, partial payouts, multiple delivery riders, expense deductions, gateway or automatic return clawback; manual full collection and payout remain independent.
- Actual MySQL contention/live APIs and Phase 10 device/email/deployment acceptance remain unverified.
- New-order buyer express fee removal is the approved necessary checkout change; selected method/labels and historical totals are preserved.
- PHP/proxy upload limits still need operator verification; notifications remain in-app; optional WASM limitation unchanged.

Authorization: continue Phases 4-10 where safe per the latest user request. Phase 3 is completed; do not reimplement it. Commits require explicit permission. No permission to invent rider earnings or payout rules.
Limitations: no automatic Codex launch after reboot, unsaved edit/process recovery, protection against disk corruption/deletion, or off-device backup. Existing valid files are preserved if atomic replacement fails.
