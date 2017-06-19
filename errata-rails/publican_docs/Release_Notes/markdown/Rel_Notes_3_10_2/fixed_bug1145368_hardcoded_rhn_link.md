### Fixed RHN links in Bugzilla comments for CDN-only advisories

When an advisory is shipped, Errata Tool posts a comment on associated
Bugzilla bugs and JIRA issues with a link to the advisory's page on
the Red Hat Customer Portal.

These links would always use the advisory's RHN URL, even if the
advisory was not distributed via RHN.  As a result, broken links were
generated for CDN-only advisories.

This has been fixed; the links used by Errata Tool when closing
Bugzilla bugs or JIRA issues now directs to RHN or CDN appropriately,
depending on the push type used for the advisory.
