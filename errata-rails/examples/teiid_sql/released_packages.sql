--
-- List latest released nvrs for a product version
-- according to the released_packages table
--
-- Uncomment full_path to show all the files in each shipped build
--
SELECT distinct
  brew_builds.id,
  brew_builds.nvr,
  -- released_packages.full_path,
  errata_main.fulladvisory,
  releases.name,
  product_versions.name
FROM
  Errata_public.released_packages
  JOIN Errata_public.product_versions ON released_packages.product_version_id = product_versions.id
  JOIN Errata_public.brew_builds ON released_packages.brew_build_id = brew_builds.id
  JOIN Errata_public.errata_main ON released_packages.errata_id = errata_main.id
  JOIN Errata_public.releases ON errata_main.group_id = releases.id
WHERE
  product_versions.name = 'RHEL-7'
  AND released_packages.current = 1
ORDER BY
  nvr
