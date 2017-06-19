--
-- List bugs and JIRA issues per release for active advisories (in a specific product)
--
SELECT
  releases.name AS release_name,
  releases.ship_date AS release_ship_date,
  errata_main.fulladvisory,
  filed_bugs.bug_id,
  jira_issues.key as jira_issue_key
FROM
  Errata_public.errata_main
  JOIN Errata_public.errata_products ON errata_main.product_id = errata_products.id
  JOIN Errata_public.releases ON errata_main.group_id = releases.id
  LEFT OUTER JOIN Errata_public.filed_bugs ON errata_main.id = filed_bugs.errata_id
  LEFT OUTER JOIN Errata_public.filed_jira_issues ON errata_main.id = filed_jira_issues.errata_id
  LEFT OUTER JOIN Errata_public.jira_issues ON filed_jira_issues.jira_issue_id = jira_issues.id
WHERE
  errata_products.short_name = 'RHOSE' AND
  errata_main.status != 'DROPPED_NO_SHIP' AND
  errata_main.status != 'SHIPPED_LIVE'
ORDER BY
  1, 2, 3, 4
