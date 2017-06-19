--
-- Show when an advisory changes states
--
SELECT
  errata_main.fulladvisory,
  users.login_name,
  state_indices.previous,
  state_indices.current,
  state_indices.created_at
FROM
  state_indices
  JOIN Errata_public.errata_main ON errata_main.id = state_indices.errata_id
  JOIN Errata_public.users ON users.id = state_indices.who_id
WHERE
  errata_main.id = 24350
;

--
-- Bonus alternative method
--
SELECT
  errata_main.fulladvisory,
  users.login_name,
  errata_activities.removed,
  errata_activities.added,
  errata_activities.created_at
FROM
  errata_activities
  JOIN Errata_public.errata_main ON errata_main.id = errata_activities.errata_id
  JOIN Errata_public.users ON users.id = who_id
WHERE
  what = 'status'
  AND errata_main.id = 24350
;
