# Finance, Collections, and Payments

## Resident account

Every resident-facing balance should be explainable as ledger entries, not a mutable balance field.

Examples:
- Rent.
- Maintenance fee.
- Utility/recharge.
- Late fee.
- Adjustment/credit.
- Payment.
- Deposit movement.

Displayed balance is derived from posted ledger entries.

## Late fees

Late fees require configurable rules:
- grace period,
- fixed or percentage fee,
- maximum/cap,
- applicable charge types,
- effective date,
- waiver/adjustment authority.

Every generated late fee must record the rule/version that created it.

## Cheques

Cheque workflow:
1. Received.
2. Receipt/reference recorded.
3. Awaiting deposit.
4. Deposited.
5. Cleared or returned.
6. Ledger posted/adjusted.

Store cheque metadata needed for reconciliation; do not store unnecessary sensitive banking information.

## Payment processing

Payment providers must sit behind an adapter.

The core system owns:
- invoice/charge identity,
- expected amount,
- resident/property attribution,
- provider payment reference,
- payment status,
- reconciliation status,
- receipt.

Provider owns sensitive card/bank handling.

Never store raw card numbers, CVV, or payment credentials.

## Maintenance fees

Maintenance fees are charge types in the same ledger and invoicing system, not a separate payment subsystem.

## Vendor invoices

Vendor/contractor invoice:
- vendor,
- work order or approved expense,
- invoice number,
- amount,
- tax where applicable,
- evidence/document,
- approval state,
- payment state,
- payment reference.

## Taxes

Property tax tracking:
- property,
- tax type,
- period,
- amount due,
- due date,
- payment state,
- payment date,
- receipt/document,
- notes.

Where direct tax payment integration is not available or appropriate, OpenHouse tracks the obligation and evidence rather than pretending to be the government payment rail.

## Shortfall financing

Represent financing as an offer from a financing provider.

Core entities:
- provider,
- eligibility result,
- amount financed,
- rate/APR or equivalent required disclosure,
- fees,
- term,
- periodic payment,
- total repayment,
- offer expiry,
- consent,
- provider application/status.

OpenHouse should not calculate or advertise financing terms that are not supplied/approved by the provider.
