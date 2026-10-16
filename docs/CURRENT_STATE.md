# Current state

- **2026-10-16 UI refinement:** existing palette retained; Rider numbering removed,
  cleaner sign-in/password visibility, grouped registration, flat panels and centered
  responsive work queues/account/photo/message screens. Browser title: ALONA Rider.
  All 93 Flutter tests PASS, including 320px layouts and 150% registration text;
  affected Dart analysis and web build PASS. Six Edge screenshots at 320/390/1440px
  reviewed; no JS exceptions. Browser checks cover login and registration's
  API-unavailable state; operational checks use mocked HTTP. ALONA backend/database
  and live acceptance remain unchanged. Design notes: docs/UI_DESIGN.md;
  local evidence: .recovery/ui-review/evidence.json.
- **2026-10-16 parcel workflow implemented locally:** approved mobile_scanner 7.4.2
  scans phone QR/barcodes containing existing ITEM references. Owned lookup opens the
  existing delivery screen; other targets retain manual entry. Mark Delivered requires
  a valid private PHOTO, server refresh and explicit confirmation. Identical proof
  retries reuse records; stale/missing files require recapture. No new schema.
- Seller delivery notifications now commit with delivery and link to owned item
  details/private photos. Other Sellers are denied; unverified legacy links are not
  guessed. Existing status/history/shipment finance retained. Live acceptance pending.
- Native Capture Proof opens
  the camera on entry, with validated preview/retake/upload and permission/busy/error
  handling. Browser/desktop select real photos. Physical camera acceptance pending.
  User confirmed the reported failure was on laptop Edge; live browser webcam capture
  is NOT IMPLEMENTED, rather than a confirmed native permission fault.
- Maps removed from pickup/delivery; Address Details uses ALONA's scoped party and
  collection/order snapshot fields. Missing fields are explicit; no guessed addresses.
- Persistent Rider notifications: owned/read/unread/timestamps/pagination/tap targets,
  foreground 30-second polling and after-commit source events. New migration prepared,
  not applied to actual database. Best effort without durable outbox; crash-after-commit
  publication gap documented. Background/push NOT IMPLEMENTED.
- My Account shows actual fields, uploads/reads private photos and edits contact plus
  canonical address. Changed address requires Logistics reapproval. Identity, vehicle,
  coverage, roles, approval and financial data remain protected. Google sign-in now
  preserves Rider-uploaded photos. No photo schema added; existing users.avatar reused.
- **Latest verification:** 72 focused Flutter tests and 59 Laravel tests/537 assertions
  PASS; affected Dart analysis clean, changed Seller Vue templates/scripts and Flutter
  web build PASS. Android debug build BLOCKED: no Android SDK. iOS requires macOS.
  Earlier Laravel batches: 52 tests/411 assertions (finance/assignment/chat/auth/profile/feed)
  and 52 tests/338 assertions (expanded feed/profile/auth/addresses/workflows/onboarding)
  PASS. Batches overlap. Only mock HTTP/enforced SQLite :memory: used in this task.
- **Preserved:** Phases 1–9 integration, real operational UI/theme/history, existing
  teammate changes, historical orders and shipment finance. One seller/new-order
  shipment, PHP 50 seller / 10 Logistics / 40 Rider after all active-member proofs;
  unique charge/earning, independent admin-only full manual collection/payout.
  New buyer shipping zero including express; metadata retained; no historical backfill.
- **Deployment BLOCKED:** populated ALONA website database is unidentified. Observed
  local .env selects empty SQLite, 51 prior migrations applied; that historical inventory
  predates the new notification migration. Actual MySQL schema/version/isolation and
  approved matching-engine copy/rehearsal required. No guessing/configuration switches.
  Prior equivalent MySQL 8.0.46 finance fixture/16 races passed; chronological fresh
  bootstrap has a pre-existing variant-FK ordering issue. No new MySQL instance here.
- **Manual PENDING:** Android/iOS camera/gallery/activity interruption/native build,
  real SMTP verification/approval, live HTTPS/API/CORS/storage/upload limits and full
  Rider/Logistics/Admin settlement acceptance. PHP upload limits previously 2M/8M are
  below application limits. Separate return/reschedule workflow NOT IMPLEMENTED.
- Optional UI preview, account/sample data and launcher were removed in the prior
  cleanup; runtime offline. No preview/database account was created or recreated.
- No actual database writes/migrations, configuration switches, resets or deployments.
  Only the approved scanner dependency was added/pinned. Rider source/UI work was
  committed and pushed to github.com/aldriannoriel/rider master on 2026-10-16:
  e427b66, independently verified against the remote. Publication receipt/checkpoint
  follows in a documentation commit; see docs/integration/GITHUB_SAVE.md.
  ALONA's existing source/staged edits remain local and were preserved.
- Next: follow docs/integration/PARCEL_DELIVERY_IMPLEMENTATION.md and ALONA
  docs/RIDER_FUNCTIONALITY.md; identify actual database before separately approved
  rehearsal/deployment. Read/verify integration recovery bundle before further work.
