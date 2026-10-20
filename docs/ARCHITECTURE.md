# Architecture

## Scope

This Flutter client uses the existing ALONA Laravel backend. ALONA owns shared
users/riders, center/area assignments, parcels, order-item tracking and private proofs.

## Components and dependencies

- `lib/main.dart` starts `RiderApp` in `lib/app.dart`; the app opens at login.
- `lib/pages/` contains login, registration, pickup dashboard, delivery
  dashboard, and proof-capture screens. Screens own their UI state and issue
  HTTP requests directly.
- `lib/services/api_config.dart` validates and normalizes URLs from `API_BASE_URL`.
- `lib/services/parcel_address.dart` resolves collection/seller pickup addresses and
  order/legacy delivery destinations. `widgets/address_details.dart` displays the
  additive scoped ALONA address DTO; dashboards no longer launch Maps.
- `lib/services/token_store.dart` uses `SharedPreferences` on web and secure
  storage on other platforms.
- `lib/widgets/failure_reason_dialog.dart` collects a delivery failure reason.
- `lib/services/rider_session.dart` checks the ALONA profile and confirms server
  logout; `rider_session_guard.dart` redirects blocked operational sessions to login.
- `profit_dashboard_page.dart` uses `RiderEarningsApi` through the shared authenticated
  `RiderPortalApi`. Typed earnings responses retain backend decimal strings. The page
  displays `total`, `outstanding`, `paid` and paginated shipment rows; it never computes
  rates, sums or payouts. Refresh/resume revisions prevent stale response overwrites.
- Direction: pages use scoped registration/session/portal adapters and the `http`
  package. ALONA owns authentication, membership, task state and persistence.
- Rider workflow additions (2026-10-20): pickup assignment acknowledgment, transit
  and paginated handoff history; delivery OTP and explicit failed-attempt retries;
  account links to COD cash, return-to-Seller jobs and supervised handovers.
  These use the shared session/portal API; physical cash/custody confirmations
  remain separate from delivery completion, Seller receipt and Logistics approval.
- `rider_presence_session.dart` shares foreground availability heartbeats across
  dashboard controls. `rider_pickup_location.dart` uses geolocator 14.0.2 for
  explicitly consented one-shot location sharing; no background location stream.

## Client navigation and request flow

`main.dart` → login → registration or, after approved/active login, pickup
dashboard → delivery dashboard → proof capture. Pickup and delivery screens can
confirm server logout before clearing the token and returning to login. Profile
checks gate login, dashboard refresh/resume/return and operations. A 401 clears
invalid credentials; denied accounts return to login with a status message.

The client references these API paths relative to `API_BASE_URL`:

- `GET /sorting-centers`, `POST /rider/register`, `POST /rider/login`
- `GET /partner/profile`, `POST /logistics/logout`
- `GET /rider/earnings?page=...` (owned backend summary and earning rows)
- `GET /rider/pickups/available`, `GET /rider/pickups/mine`
- `POST /rider/pickups/{id}/accept`, `POST /rider/pickups/{id}/confirm`
- `GET /rider/deliveries`
- `GET /rider/deliveries/lookup?reference=ITEM-...` resolves only an approved Rider's
  active assigned parcel; the Sorting Center lookup remains separately authorized.
- `POST /rider/deliveries/{id}/start`, `/deliver`, `/fail`, and
  `/upload-proof`

These request targets match ALONA routes/api.php. Registration uses existing ALONA partner/address/coverage contracts; operations use Sanctum and approved Rider middleware. Responses
are decoded into dynamic maps for operational screens/session helpers. Earnings use
validated `RiderEarningsPage`/`RiderEarning` response classes with string money values.

## Integrations and runtime

- ALONA API_BASE_URL is configurable at build/run time. Web debug defaults to
  http://localhost:8000/api; native builds require an explicit reachable URL and
  release requires explicit HTTPS (see README).
- `file_picker` handles registration documents; `image_picker` captures native proof
  photos and selects actual gallery images for profile/unsupported-camera targets.
- User-approved `mobile_scanner` 7.4.2 supplies Android/iOS QR/barcode decoding.
  `parcel_scanner_page.dart` owns camera lifecycle, explicit rescan/duplicate guards
  and manual reference fallback on other targets; `RiderParcelApi` validates/scopes
  lookup. It opens the existing delivery page with a single parcel filter.
- Mark Delivered uses additive backend `has_valid_photo_proof`, mandatory capture
  when absent, server refresh, Buyer OTP confirmation and `DeliverySuccessPage` after
  success only. PHOTO/private-file eligibility and upload dedupe stay in Laravel;
  historical deliveries/financial rules are preserved. Errors keep a stale-photo
  rejection actionable for recapture. No new real-time service or schema in this batch.
- Flutter platform projects exist for Android, iOS, web, Windows, macOS, and
  Linux. README run instructions cover local development API connectivity.

## Tests and limits

`test/widget_test.dart` verifies login rendering. api_config_test.dart checks URL
configuration, endpoint paths and HTTP connectivity against a temporary test server.
rider_session_test.dart covers readiness, invalid tokens, logout confirmation/retry,
dashboard blocking and resume checks. parcel_address_test.dart covers legacy/missing
addresses. ALONA has separate Logistics workflow tests; the full client-to-ALONA
authenticated workflow remains unverified.
Recheck the relevant source when behavior changes; avoid broad scans of
generated platform/build output.

RegistrationApi builds canonical multipart fields and array keys, intersects published
coverage partners, and queries existing geographic directories. Proof capture uses
XFile bytes and private multipart uploads; assigned delivery responses include
has_delivery_proof. API errors use a shared safe message mapper.

Verified remaining integration surfaces (2026-10-15):

- Existing GET /rider/deliveries accepts view=history with bounded pagination and
  owned status counts; default active-list behavior is preserved. Phase 7 earnings
  are calculated by ALONA's shipment finance service and exposed through owned
  GET /rider/earnings. Existing Rider tools and a history link open the earnings view;
  delivery-history endpoints/pagination and operational layouts remain unchanged.
- RiderPortalApi / rider_portal_page.dart retain scoped Logistics chat and tools.
  rider_notifications_page.dart uses persisted owned GET /rider/notifications and
  POST /rider/notifications/{id}/read; foreground/current-screen polling every 30s,
  resume/return refresh, bounded paging, unread/read timestamps and related-screen taps.
  ALONA source observers publish after commit with unique event keys; best effort,
  without durable replay or device push. Migration is prepared, not deployed.
- rider_account_page.dart reads actual GET /partner/profile fields and authenticated
  private photo bytes, edits contact through PATCH /rider/profile and uploads photos
  to POST /rider/profile-photo. rider_address_edit_page.dart reuses public PSGC
  directories and submits canonical addresses requiring Logistics reapproval.
  Protected identity/vehicle/coverage/approval/finance cannot be edited here.
- Login preserves exact legacy email matches and supports canonical lowercase new
  registrations. Private proof uploads lock the parcel and clean up on record failure.
- Integration recovery state is in docs/integration; scripts flush/replace/verify
  checkpoints, guard Laravel tests against cached configuration, and can restore
  coherent previous docs while archiving interrupted notes.

Financial boundary verified 2026-10-15: ALONA Commission records belong to orders
and sellers; order shipping_fee is an order charge. Neither inspected path defines
rider compensation. Parcels link uniquely to optional order items and separately
reference pickup/assigned riders; their ITEM scan reference is not a parent order ID.
Phase 7 now adds seller_shipments (one per seller/new order) with fixed item membership,
seller_delivery_charges (unique shipment) and rider_delivery_earnings (unique charge).
Existing parcel APIs enforce one shipment rider/center and recognize PHP 50/10/40
only after all noncancelled parcel proofs. Manual collection and payout are separate
admin-only full settlements. Historical orders retain their totals/null memberships;
new buyer shipping is zero, including express, with method behavior retained.
Migration created/tested in isolation, not deployed. See ALONA docs/DELIVERY_FINANCE.md
and its project-local architecture map; DECISIONS.md records approved policy.
