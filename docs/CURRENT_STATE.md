# Current state

- **Verified 2026-10-15:** Phases 1–3 implemented. Configurable ALONA API URLs,
  safe pickup/delivery addresses, confirmed server logout and current-profile checks.
- Logout uses the existing API; confirmed JSON success or Sanctum 401 clears local
  credentials. Network, timeout, unexpected responses and server failures preserve
  credentials for retry and explicitly state revocation is unconfirmed.
- Login, dashboard refresh/resume/return and Rider actions require approved account
  and rider profile, activity and conditional email verification. Authorization
  failures recheck readiness; blocked accounts return to login. Invalid tokens clear.
- ALONA profile adds Rider is_active/verification_required. Assignment list/submission
  share an eligibility query matching operational middleware, preserving legacy
  riders' verification exemption. Existing backend/database and UI styling are reused.
- Validation: 41 focused Flutter tests and 33 isolated in-memory Laravel tests pass.
  Scoped Dart analysis has no errors/warnings and four existing proof-radio
  deprecation notices. Device/production connectivity and full workflow are unverified.
- **Planned, awaiting approval:** Phase 4 partner registration contract; Phase 5
  broad API error handling; Phase 6 complete workflow verification. Registration
  still sends its legacy payload. Do not begin Phase 4 without user approval.
