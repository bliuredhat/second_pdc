### Fix Errata-Jira issues sync background job getting stuck

When Errata Tool tried to sync a JIRA issue that it was unable to access, it
would fail but keep the record to indicate that a sync was still required. This
would cause the inaccessible JIRA issue sync to be retried repeatedly. Over time,
when the number of these un-syncable issues reached the batch size of the sync
job, it would cause syncing to stop working.

This has been fixed by deleting the dirty issue record for issues that were
unable to be synced so they are not retried over and over again.
