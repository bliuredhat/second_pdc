--
-- Shows how many advisories are in each release
--
SELECT
  releases.name,
  count(*) as errata_count
FROM
  Errata_public.errata_main
  JOIN Errata_public.releases ON errata_main.group_id = releases.id
GROUP BY
  releases.name
-- (Let's also collect the releases with no advisories)
UNION SELECT
  releases.name,
  0 as errata_count
FROM
  Errata_public.releases
WHERE
  Errata_public.releases.id NOT IN (SELECT DISTINCT group_id FROM errata_main)
ORDER BY
  2 desc
;
