### Fixed 'ambiguous identifiers' error on erratum API update

In some circumstances, the api/v1/erratum API would fail when
trying to update an advisory, with an error message about
'ambiguous identifiers'. This would occur if a JIRA issue
was assigned to the advisory, and that issue key matched a
Bugzilla alias.

This has now been fixed.
