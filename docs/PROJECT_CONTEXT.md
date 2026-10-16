# Project context

- **Purpose:** Flutter courier client for the existing ALONA Laravel API. ALONA
  remains the single backend and database; no separate Logistics backend is needed.
- **Users:** Riders who register, check approval, accept pickups, and deliver parcels.
- **Scope:** Flutter client integration with ALONA's existing Rider/Logistics APIs.
- **Constraints:** Preserve the existing colors, shared authentication, and ALONA
  Buyer/Seller/Admin/Logistics behavior. Never use a buyer destination for pickup.
- **Current authorization:** Phase 7 backend and Rider earnings API integration
  implemented. Current functionality fixes cover native camera/proof, Address Details,
  persisted in-app notifications and permitted profile/photo/address updates.
  Approved follow-up adds phone QR/barcode/owned parcel lookup, mandatory PHOTO
  completion and Seller delivery notices/private proof viewing using existing tables.
  Preserve colors, operational rules/history and historical orders; no preview data.
  No automatic commit, push, reset or production migration/data operation.
  Read docs/integration/RESUME.md and PHASE10_READINESS.md for remaining checks.
- **Approved UI refinement (2026-10-16):** remove decorative Rider numbering and
  simplify spacing, typography, forms and panels while retaining colors and workflows.
  Presentation guidance: docs/UI_DESIGN.md.
