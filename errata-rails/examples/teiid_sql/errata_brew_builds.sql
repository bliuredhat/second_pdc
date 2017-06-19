--
-- Joining advisories to their builds
-- (Shows active advisories only)
--
SELECT
  errata_main.id,
  errata_main.fulladvisory,
  errata_main.status,
  brew_builds.id AS brew_build_id,
  packages.name AS package_name,
  brew_builds.version,
  brew_builds.release,
  product_versions.name AS product_version_name
FROM
  Errata_public.errata_main
  JOIN Errata_public.errata_brew_mappings ON errata_main.id = errata_brew_mappings.errata_id AND errata_brew_mappings.current = 1
  JOIN Errata_public.brew_builds ON errata_brew_mappings.brew_build_id = brew_builds.id
  JOIN Errata_public.packages ON brew_builds.package_id = packages.id
  JOIN Errata_public.product_versions ON errata_brew_mappings.product_version_id = product_versions.id
WHERE
  errata_main.status IN ('NEW_FILES', 'QE', 'REL_PREP', 'PUSH_READY', 'IN_PUSH')
ORDER BY
  errata_main.id desc
;
