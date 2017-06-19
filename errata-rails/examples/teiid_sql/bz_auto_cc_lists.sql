--
-- Lookup who is on auto cc lists in Bugzilla.
--
-- Sometimes it's useful to see who is on the automatic cc-lists for new Errata
-- Tool bugs, for example when onboarding new developers, or when there is a
-- new component added. Using a Teiid query is a good way to do that. (Actually
-- I don't know any other way).
--
-- Example usage:
--
--   ./teiid_query.sh bz_auto_cc_lists.sql | grep sbaird
--
SELECT
  products.name,
  components.name,
  profiles.login_name
FROM
  Bugzilla.products
  JOIN Bugzilla.components   ON products.id          = components.product_id
  JOIN Bugzilla.component_cc ON components.id        = component_cc.component_id
  JOIN Bugzilla.profiles     ON component_cc.user_id = profiles.userid
WHERE
  products.name = 'Errata Tool' -- adjust as required
ORDER BY
  products.name,
  components.name,
  profiles.login_name
;
