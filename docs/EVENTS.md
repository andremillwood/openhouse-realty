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


## Tours and open houses
- open_house.published
- open_house.rsvp_created
- open_house.checked_in
- tour.requested
- tour.completed

## Security and access
- visitor.expected
- visitor.checked_in
- visitor.checked_out
- worker.checked_in
- worker.checked_out
- incident.reported
- incident.resolved

## Finance and collections
- charge.posted
- late_fee.posted
- cheque.received
- cheque.deposited
- cheque.cleared
- cheque.returned
- invoice.submitted
- invoice.approved
- invoice.paid
- tax.due
- tax.paid
- financing_offer.created
- financing_offer.accepted

## Mobile
- device.registered
- push.requested
- push.delivered
