--
-- Number of advisories shipped per week
--
SELECT
  YEAR(actual_ship_date) || '-' || LPAD(WEEK(actual_ship_date), 2, '0') AS week,
  COUNT(id) AS shipped_count
FROM
  errata_main
WHERE
  NOT actual_ship_date IS NULL AND
  status = 'SHIPPED_LIVE'
GROUP BY
  YEAR(actual_ship_date),
  WEEK(actual_ship_date)
ORDER BY
  1
