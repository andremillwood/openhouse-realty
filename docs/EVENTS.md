# Domain Event Catalog

Initial event names are contracts, not implementation details.

## Marketplace
- listing.published
- listing.viewed
- listing.saved
- listing.hidden
- listing.shared
- search.performed
- preference.updated
- recommendation.shown
- recommendation.opened

## Leasing
- viewing.requested
- viewing.confirmed
- viewing.completed
- application.started
- application.submitted
- application.approved
- application.declined
- lease.prepared
- lease.signed

## Seller
- seller_lead.created
- seller_review.requested
- listing_agreement.signed
- offer.received

## Property operations
- unit.market_ready
- service.reported
- work_order.assigned
- work_order.completed
- inspection.completed
- turnover.completed

## Finance
- payment.received
- invoice.approved
- deposit.refund_ready

## Notification rule

Events may trigger email, WhatsApp/SMS, in-app notifications, tasks, analytics, or recommendation recalculation. Those effects belong in handlers, not the initiating UI.
