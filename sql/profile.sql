SELECT k, COUNT(*) AS rows_with_field
FROM raw.permits, jsonb_object_keys(payload) k
GROUP BY k ORDER BY rows_with_field desc;

SELECT payload->>'permit_' AS permit, COUNT(*)
FROM raw.permits 
GROUP BY 1 HAVING COUNT(*) > 1 ORDER BY 2 DESC LIMIT 20;

-- total rows, partitions loaded, date range
SELECT COUNT(*), COUNT(DISTINCT partition_date),
       MIN(payload->>'issue_date'), MAX(payload->>'issue_date')
FROM raw.permits;

-- present-but-empty values
SELECT COUNT(*) FILTER (WHERE payload->>'permit_status' = '') AS empty_status,
       COUNT(*) FILTER (WHERE payload->>'work_type' = '') AS empty_work_type
FROM raw.permits;

-- does the fee data reconcile?
SELECT COUNT(*) FROM raw.permits
WHERE (payload->>'building_fee_subtotal')::numeric
   <> (payload->>'building_fee_paid')::numeric
    + (payload->>'building_fee_unpaid')::numeric
    + (payload->>'building_fee_waived')::numeric;

-- coordinates outside Chicago (rough bounding box)
SELECT COUNT(*) FROM raw.permits
WHERE (payload->>'latitude')::numeric NOT BETWEEN 41.6 AND 42.1
   OR (payload->>'longitude')::numeric NOT BETWEEN -87.95 AND -87.5;

-- issue_date should match its partition
SELECT COUNT(*) FROM raw.permits
WHERE LEFT(payload->>'issue_date', 10) <> partition_date::text;

-- application should start on or before issue
SELECT COUNT(*) FROM raw.permits
WHERE (payload->>'application_start_date')::date > (payload->>'issue_date')::date;

-- fee fields: do totals add up across fee types?
SELECT COUNT(*) FROM raw.permits
WHERE (payload->>'total_fee')::numeric
   <> (payload->>'building_fee_subtotal')::numeric
    + (payload->>'zoning_fee_subtotal')::numeric
    + (payload->>'other_fee_subtotal')::numeric;
