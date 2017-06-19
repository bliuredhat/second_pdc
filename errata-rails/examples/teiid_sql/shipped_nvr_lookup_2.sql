--
-- For a given nvr find what advisory it was shipped in
-- (by looking at the errata brew mappings).
--
SELECT distinct
  brew_builds.nvr,
  errata_main.fulladvisory,
  errata_main.actual_ship_date,
  product_versions.name AS product_version_name,
  releases.name AS release_name
FROM
  brew_builds
  JOIN errata_brew_mappings ON brew_builds.id = errata_brew_mappings.brew_build_id
  JOIN product_versions ON product_versions.id = errata_brew_mappings.product_version_id
  JOIN errata_main ON errata_main.id = errata_brew_mappings.errata_id
  JOIN Errata_public.releases ON releases.id = errata_main.group_id
WHERE
  errata_main.status = 'SHIPPED_LIVE'
  AND brew_builds.nvr = 'vim-7.4.629-5.el6'
  -- AND brew_builds.nvr like 'vim%'
