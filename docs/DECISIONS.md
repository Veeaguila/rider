# Decisions

## 2026-10-15 — Seller-funded delivery earnings

**Business policy and shipment design: approved. Backend and Rider API view implemented; deployment pending.**

Seller funds PHP 50 per successful seller package/shipment, never per individual
parcel: Logistics 20% (PHP 10), Rider 80%
(PHP 40). Seller vouchers/free shipping never reduce either allocation. Track
product and shipping discounts separately. Recognize rider earnings only on
confirmed successful delivery; failed deliveries/returns generate no additional
earnings. Exclude pickup-only fees and expenses for now. Collection and payouts
remain manual, with seller liabilities, rider earnings and payout statuses tracked
separately; prevent duplicate charges/earnings. Future pricing may use weight,
quantity and parcel size, so preserve the applied pricing rule/amounts.

Apply only to new orders; remove their buyer shipping charges including express
after reviewing express behavior. Preserve historical totals, with no backfill.
Multiple parcels in one shipment must not duplicate fees/earnings. Keep Rider UI
and Delivery History unchanged. Manual settlements support full payments only.

Do not reuse marketplace commission or buyer payment status for delivery finance.
The scoped audit found no persisted identifier. User subsequently approved one
seller shipment per seller/new order, fixed item membership, one delivery rider,
all noncancelled parcel proofs before accrual, and no split shipments/partial payouts.
ALONA now implements that model. Express method behavior remains; zero new-order
buyer express shipping is the approved necessary pricing change. Historical totals
remain intact. No application database migration was run outside isolated tests.

Lock parent order before shipment/member/parcel rows so package finance and shared
order aggregation serialize consistently. Read members/proofs with locking queries
to avoid stale MySQL REPEATABLE READ snapshots after waiting on sibling completion.
Deployment-engine contention testing remains pending; see ALONA docs/DELIVERY_FINANCE.md.

Rider displays ALONA total/paid/outstanding decimal strings and earning rows through
the authenticated earnings API. No client fee/percentage/total computation or paid
action. A separate earnings page reuses existing UI patterns and preserves Delivery
History. This final integration is local; no automatic commit or push is authorized.

## Parcel workflow follow-up (2026-10-16)

User approved mobile_scanner 7.4.2, pinned exactly. Decode existing ITEM references;
owned API lookup authorizes before navigation. Native Android/iOS scanning only;
manual reference entry remains available on other targets.

New completion attempts require assigned-rider PHOTO plus readable validated private
image, followed by explicit client confirmation. Historical completed rows remain
unchanged. Reuse existing proof, parcel/item and SellerNotification tables; commit
Seller delivery notice atomically and expose only owner-checked private photos.
Unverified legacy Seller links are omitted rather than guessed. Finance unchanged.
