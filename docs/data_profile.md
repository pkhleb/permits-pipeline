# Data profile: Chicago building permits (raw layer)

**Source:** City of Chicago building permits API
**Loaded:** 2,751 permits across 30 daily partitions (issue dates 2026-10-01 to 2026-10-30)

## Completeness
- 29 fields are present on every row (e.g. id, permit_, issue_date, permit_type,
  total_fee, all fee fields, street fields, contact_1_name/type).
- Gaps (rows missing the field out of 2,751):
  - work_type: 924 (33.6%)
  - pin_list: 603 (21.9%)
  - reported_cost: 377 (13.7%)
  - permit_status / permit_milestone: 266 (9.7%)
  - latitude / longitude / location: 41 (1.5%)
  - ward / community_area: 29 (1.1%)
  - permit_condition: present on only 237 rows (8.6%)
- Missing values are omitted keys (nulls), not empty strings. Checked
  permit_status and work_type: 0 empty strings.

## Integrity checks (all passed on this load)
- Duplicate permit_ values: 0
- building_fee_subtotal = paid + unpaid + waived: 0 mismatches
- Coordinates outside Chicago bounding box: 0 (of 2,710 rows with coordinates)
- issue_date does not match partition_date: 0 rows
- application_start_date after issue_date: 0 rows
- total_fee != building + zoning + other subtotals: 0 rows

## Structure
- Contacts are stored as 10 repeating column groups (contact_N_name/type/city/
  state/zipcode, ~50 columns). Contact 1 is on every row; contact 10 on 13 rows.
  Plan: unpivot into a permit_contacts table (one row per contact).

## Planned tests
- not_null: permit_, id, issue_date, permit_type
- unique: permit_, id
- fee reconciliation, coordinate bounds, issue_date matches partition_date
- warn if permit_status null rate rises above a threshold
