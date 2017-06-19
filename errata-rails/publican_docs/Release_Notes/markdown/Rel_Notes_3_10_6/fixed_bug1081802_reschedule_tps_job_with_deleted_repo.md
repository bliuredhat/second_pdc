### Fixed rescheduling TPS jobs when a job's CDN repo was deleted

In earlier versions of Errata Tool, if a CDN repo was removed from the
system, any TPS jobs which used that repo would trigger a crash when
attempting to reschedule jobs.

This could block the transition of an advisory from NEW_FILES to QE,
since that transition includes TPS job rescheduling.

This has been fixed.  Jobs with deleted repos no longer cause a crash;
instead, they are gracefully removed at the next TPS rescheduling.
tps.txt is also regenerated after deleting a repo to ensure that any
jobs for the deleted repo are promptly removed from the TPS queue.
