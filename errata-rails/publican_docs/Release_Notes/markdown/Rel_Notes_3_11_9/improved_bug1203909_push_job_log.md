### Improved logging of post-push task execution

When Errata Tool executes post-push tasks, some tasks are only run if certain
criteria is met. For example, an advisory may not be marked as `SHIPPED_LIVE`
until both RHN and CDN pushes have completed.

In previous versions of Errata Tool, any tasks whose execution were skipped
would simply be omitted from the push log, with no indication of why the task
was not run.

This has been improved. Any skipped task is now included in the push job log
with an explanatory message, as in the following example:

    2015-09-14 19:37:02 -0400 Pub completed.
    2015-09-14 19:37:03 -0400 Skipping task update_push_count: cdn push is not complete. Depends on: cdn, rhn_live
    2015-09-14 19:37:04 -0400 Skipping task mark_errata_shipped: cdn push is not complete. Depends on: cdn, rhn_live
    2015-09-14 19:37:04 -0400 Skipping task update_jira: cdn push is not complete. Depends on: cdn, rhn_live
    2015-09-14 19:37:04 -0400 Skipping task update_bugzilla: cdn push is not complete. Depends on: cdn, rhn_live
    2015-09-14 19:37:04 -0400 Skipping task move_pushed_errata: cdn push is not complete. Depends on: cdn, rhn_live
    2015-09-14 19:37:04 -0400 Running post push tasks.
    2015-09-14 19:37:04 -0400 Running post push tasks: check_error
    2015-09-14 19:37:04 -0400 Running mandatory tasks check_error
    2015-09-14 19:37:04 -0400 Running task check_error
    2015-09-14 19:37:05 -0400 Running remainder:
    2015-09-14 19:37:05 -0400 Post push tasks complete
