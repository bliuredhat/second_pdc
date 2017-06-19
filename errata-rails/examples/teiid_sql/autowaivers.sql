--
-- Read details about RPMDiff autowaive rule definitions
--
SELECT
  package_name,
  product_versions.name as product_version,
  rpmdiff_tests.description AS test,
  subpackage,
  reason,
  users1.login_name AS created_by,
  users2.login_name AS approved_by,
  content_pattern
FROM
  rpmdiff_autowaive_rule
  JOIN rpmdiff_tests ON rpmdiff_autowaive_rule.test_id = rpmdiff_tests.test_id
  JOIN rpmdiff_autowaive_product_versions ON
    rpmdiff_autowaive_rule.autowaive_rule_id = rpmdiff_autowaive_product_versions.autowaive_rule_id
  JOIN product_versions ON rpmdiff_autowaive_product_versions.product_version_id = product_versions.id
  JOIN Errata_public.users AS users1 ON rpmdiff_autowaive_rule.created_by = users1.id
  JOIN Errata_public.users AS users2 ON rpmdiff_autowaive_rule.approved_by = users2.id
WHERE
  active = 1
ORDER BY
  1, 2, 3, 4
