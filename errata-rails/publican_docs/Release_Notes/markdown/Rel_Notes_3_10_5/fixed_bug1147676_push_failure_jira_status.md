### Fixed push failures due to bad JIRA status

When JIRA issues have been associated with an advisory, Errata Tool
attempts to close the issues on shipping the advisory.

In earlier versions of Errata Tool, there was a strict check during
the pre-push of an advisory to ensure that all associated issues were
permitted to be closed according to the configured JIRA workflow.  If
any issue was not permitted to be closed, the push would be forbidden.

In practice, this restriction turned out to be user-unfriendly and too
strict.  On a few occasions, it disrupted the delivery of errata.

This restriction has been weakened.  Errata Tool now attempts to close
JIRA issues when shipping an advisory, but falls back to posting a
comment if workflow restrictions prevent closing issues.
