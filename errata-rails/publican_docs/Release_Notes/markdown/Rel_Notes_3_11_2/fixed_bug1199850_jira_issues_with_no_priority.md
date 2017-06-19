### Fixed handling of JIRA issues with no priority

JIRA issues most often have an associated Priority value.  However, in
some cases, a JIRA project may be configured to allow issues with no
Priority.

A bug in Errata Tool prevented such issues from being used.
Attempting to synchronize an issue without a priority, or add such an
issue to an advisory, would cause an internal server error.

This has been fixed, allowing Errata Tool to correctly handle JIRA
issues with no priority.
