--
-- Fetching a list of Covscan test runs via Teiid
-- See also:
--   https://errata.devel.redhat.com/user-guide/covscan-static-analysis-coverity-scan-diffs.html
--
SELECT
  external_test_runs.id,
  external_test_runs.external_id AS covscan_id,
  external_test_runs.brew_build_id,
  brew_builds.nvr,
  external_test_runs.status,
  errata_main.fulladvisory,
  product_versions.name AS product_version_name,
  external_test_runs.external_status,
  external_test_runs.external_message,
  external_test_runs.created_at,
  external_test_runs.updated_at
FROM
  Errata_public.external_test_runs
  JOIN Errata_public.external_test_types ON external_test_types.id = external_test_runs.external_test_type_id
  -- So we can see the advisory name and build nvr
  JOIN Errata_public.brew_builds ON brew_builds.id = external_test_runs.brew_build_id
  JOIN Errata_public.errata_main ON errata_main.id = external_test_runs.errata_id
  -- So we can see the product version
  JOIN Errata_public.errata_brew_mappings ON errata_brew_mappings.errata_id = errata_main.id AND errata_brew_mappings.brew_build_id = brew_builds.id
  JOIN Errata_public.product_versions ON product_versions.id = errata_brew_mappings.product_version_id
WHERE
  external_test_types.name = 'covscan'
  -- Filter as required, for example
  --AND brew_builds.nvr LIKE 'bash%'
ORDER BY
  external_test_runs.id DESC
LIMIT
  50
;
