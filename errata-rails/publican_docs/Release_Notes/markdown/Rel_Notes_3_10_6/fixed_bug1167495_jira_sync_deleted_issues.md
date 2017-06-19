### Fixed JIRA synchronization blocked by deleted issues

A bug in the JBoss JIRA to Errata Tool synchronization process meant
that the sync could stall if any issues had been deleted from JIRA.

This has been fixed.  Deleted JIRA issues are now ignored by the sync
process.
