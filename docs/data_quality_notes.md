# GrowthOS Data Quality Notes

## Dataset

Google public obfuscated GA4 ecommerce sample.

Date range: November 1, 2020 through January 31, 2021.

## Order and item checks

- Total unique transactions: 4,452
- Total purchased item rows: 13,222
- Orders with repeated purchase events: 327
- Orders spanning multiple sessions: 16
- Orders with missing event-level revenue: 0
- Orders without item rows: 0
- Orders reconciled within $1: 4,365
- Orders with a revenue gap greater than $1: 87
- Average absolute order-to-item revenue gap: $0.54

## Interpretation

The source dataset is obfuscated and may contain placeholder,
missing, duplicated, or internally inconsistent values.

Transactions are preserved rather than silently deleted.
Duplicate purchase events are consolidated at transaction grain.
The earliest item-bearing purchase event is used as the canonical
source for purchased line items.

Revenue reconciliation differences are documented and should not
be interpreted as current Google Merchandise Store performance.