--
-- For a given nvr find what advisory it was shipped in
-- (by looking in released_packages).
--
SELECT distinct
  brew_builds.nvr,
  errata_main.fulladvisory,
  errata_main.actual_ship_date,
  product_versions.name AS product_version_name,
  releases.name AS release_name
FROM
  released_packages
  JOIN brew_builds ON brew_builds.id = released_packages.brew_build_id
  JOIN product_versions ON product_versions.id = released_packages.product_version_id
  JOIN errata_main ON errata_main.id = released_packages.errata_id
  JOIN Errata_public.releases ON releases.id = errata_main.group_id
WHERE
  brew_builds.nvr = 'vim-7.4.629-5.el6'
  -- brew_builds.nvr like 'vim%'
