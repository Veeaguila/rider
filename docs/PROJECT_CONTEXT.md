# Project context

- **Purpose:** Flutter courier client for the existing ALONA Laravel API. ALONA
  remains the single backend and database; no separate Logistics backend is needed.
- **Users:** Riders who register, check approval, accept pickups, and deliver parcels.
- **Scope:** Flutter client integration with ALONA's existing Rider/Logistics APIs.
- **Constraints:** Preserve the current UI design, shared authentication, and ALONA
  Buyer/Seller/Admin/Logistics behavior. Never use a buyer destination for pickup.
- **Current authorization:** Approved Phase 7 shipment grouping/schema/APIs implemented
  in ALONA; preserve Rider UI/Delivery History and historical totals. No automatic
  production migration/data operation, commit or push. Read integration/RESUME.md
  and ALONA docs/DELIVERY_FINANCE.md for deployment/manual verification limits.
