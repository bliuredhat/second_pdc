--
-- List comments for a single advisory including what state
-- the advisory was in when the comment was added
--
SELECT
  errata_main.fulladvisory,
  state_indices.current,
  users.login_name,
  comments.text,
  comments.created_at
FROM
  Errata_public.comments
  JOIN Errata_public.errata_main ON errata_main.id = comments.errata_id
  JOIN Errata_public.users ON users.id = comments.who_id
  JOIN Errata_public.state_indices ON state_indices.id = comments.state_index_id
WHERE
  errata_main.id = 24350
ORDER BY
  created_at
;
