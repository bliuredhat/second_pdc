--
-- Shows how to join releases to product versions
--
-- Notes:
-- * A release that doesn't specify its product versions is considered
--   unlimited, i.e. it could possibly have any product version.
-- * The ASYNC release is a special one that is used for many product
--   versions as you can see if you run this query.
--
SELECT
  releases.id,
  releases.name,
  releases.description,
  releases.type,
  releases.ship_date,
  releases.enabled,
  releases.isactive,
  product_versions.id AS product_version_id,
  product_versions.name AS product_version_name
FROM
  Errata_public.releases
  LEFT OUTER JOIN Errata_public.product_versions_releases ON releases.id = product_versions_releases.release_id
  LEFT OUTER JOIN Errata_public.product_versions ON product_versions_releases.product_version_id = product_versions.id
ORDER BY
  releases.name,
  product_versions.name
;
