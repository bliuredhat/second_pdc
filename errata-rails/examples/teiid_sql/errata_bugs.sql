--
-- How to join advisories to their bugs
-- This example lists all bugs in RHEL 7.2 advisories
--
-- Note there's a filed_jira_issues table that you can join in
-- a similar way to list JIRA issues.
--
SELECT
  errata_main.id,
  errata_main.fulladvisory,
  filed_bugs.bug_id,
  Errata_public.bugs.short_desc,
  Bugzilla.bugs.priority,
  Bugzilla.bugs.bug_severity
FROM
  Errata_public.errata_main
  JOIN Errata_public.releases ON errata_main.group_id = releases.id
  JOIN Errata_public.filed_bugs ON errata_main.id = filed_bugs.errata_id
  JOIN Errata_public.bugs ON Errata_public.bugs.id = filed_bugs.bug_id
  -- We can also join into Bugzilla
  JOIN Bugzilla.bugs ON Bugzilla.bugs.bug_id = filed_bugs.bug_id
WHERE
  releases.name = 'RHEL-7.2.0'
  AND errata_main.status = 'SHIPPED_LIVE'
ORDER BY
  errata_main.id ASC,
  filed_bugs.bug_id ASC
