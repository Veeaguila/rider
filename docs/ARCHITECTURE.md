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
  order/legacy delivery destinations; dashboards block Maps for missing locations.
- `lib/services/token_store.dart` uses `SharedPreferences` on web and secure
  storage on other platforms.
- `lib/widgets/failure_reason_dialog.dart` collects a delivery failure reason.
- `lib/services/rider_session.dart` checks the ALONA profile and confirms server
  logout; `rider_session_guard.dart` redirects blocked operational sessions to login.
- Direction: pages depend on shared URL/token/session services and the `http` package;
  no separate API client, repository, or typed data-model layer is present.

## Client navigation and request flow

`main.dart` → login → registration or, after approved/active login, pickup
dashboard → delivery dashboard → proof capture. Pickup and delivery screens can
confirm server logout before clearing the token and returning to login. Profile
checks gate login, dashboard refresh/resume/return and operations. A 401 clears
invalid credentials; denied accounts return to login with a status message.

The client references these API paths relative to `API_BASE_URL`:

- `GET /sorting-centers`, `POST /rider/register`, `POST /rider/login`
- `GET /partner/profile`, `POST /logistics/logout`
- `GET /rider/pickups/available`, `GET /rider/pickups/mine`
- `POST /rider/pickups/{id}/accept`, `POST /rider/pickups/{id}/confirm`
- `GET /rider/deliveries`
- `POST /rider/deliveries/{id}/start`, `/deliver`, `/fail`, and
  `/upload-proof`

These request targets match ALONA routes/api.php. Registration payload compatibility
remains planned; operations use Sanctum and approved Rider middleware. Responses
are decoded into dynamic maps in the screens and session helper; there are
no dedicated model classes in the client.

## Integrations and runtime

- ALONA API_BASE_URL is configurable at build/run time. Debug defaults to
  http://localhost:8000/api; release requires explicit HTTPS. Emulators/devices
  require a URL reachable from that target (see README).
- `file_picker` handles registration documents; `image_picker` captures proof
  photos; `url_launcher` opens map URLs.
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
