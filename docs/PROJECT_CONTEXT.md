# Project context

- **Purpose:** Flutter courier client for the existing ALONA Laravel API. ALONA
  remains the single backend and database; no separate Logistics backend is needed.
- **Users:** Riders who register, check approval, accept pickups, and deliver parcels.
- **Scope:** Flutter client integration with ALONA's existing Rider/Logistics APIs.
- **Constraints:** Preserve the current UI design, shared authentication, and ALONA
  Buyer/Seller/Admin/Logistics behavior. Never use a buyer destination for pickup.
- **Current authorization:** Phases 1–3 implemented; Phase 4 and later require
  further user approval.
