--
-- Basic example showing how to join a few useful tables to errata_main.
-- (Remove the LIMIT to get all advisories)
--
SELECT
  errata_main.id,
  errata_main.fulladvisory,
  errata_main.synopsis,
  errata_main.status,
  errata_main.errata_type,
  errata_main.created_at,

  -- Note confusing schema here
  errata_main.release_date AS embargo_date,

  -- Often this is nil which means use date from batch or release
  errata_main.publish_date_override,

  batches.release_date as batch_release_date,
  releases.ship_date as release_ship_date,

  -- The effective release date is derived like this. Nil here means asap.
  COALESCE(errata_main.publish_date_override, batches.release_date, releases.ship_date) as effective_release_date,

  -- This is set when advisory is actually shipped
  errata_main.actual_ship_date,

  live_advisory_names.year,
  live_advisory_names.live_id,

  users1.login_name AS reporter,
  users2.login_name AS assigned_to,

  batches.id AS batch_id,
  batches.name AS batch_name,

  releases.id AS release_id,
  releases.name AS release_name,

  -- These are large fields so will comment them out for the example
  -- errata_content.topic,
  -- errata_content.description,
  -- errata_content.solution,

  errata_products.id AS product_id,
  errata_products.short_name AS product_short_name,
  errata_products.name AS product_name

FROM
  Errata_public.errata_main
  JOIN Errata_public.releases ON errata_main.group_id = releases.id
  LEFT OUTER JOIN Errata_public.batches ON errata_main.batch_id = batches.id
  JOIN Errata_public.errata_products ON releases.product_id = errata_products.id
  JOIN Errata_public.errata_content ON errata_main.id = errata_content.errata_id
  JOIN Errata_public.users AS users1 ON errata_main.reporter_id = users1.id
  JOIN Errata_public.users AS users2 ON errata_main.assigned_to_id = users2.id
  LEFT OUTER JOIN Errata_public.live_advisory_names ON errata_main.id = live_advisory_names.errata_id
WHERE
  errata_main.status != 'DROPPED_NO_SHIP'
ORDER BY
  errata_main.id desc
LIMIT
  100
;
