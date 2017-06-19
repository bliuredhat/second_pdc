--
-- How to look up an approved component list in Bugzilla
--
SELECT
  r.description,
  c.name
FROM
  Bugzilla.rh_release AS r
  JOIN Bugzilla.rh_release_components AS rc ON rc.release_id = r.id
  JOIN Bugzilla.components AS c ON c.id = rc.component_id
WHERE
  r.description LIKE '%Red Hat Enterprise Linux 7.1.0%' -- adjust as required
ORDER BY
  r.description,
  c.name
;
