### Fixed "Check status now" triggering duplicate post-push tasks

Normally, Errata Tool periodically checks the status of ongoing pub tasks in the
background.

In Errata Tool 3.10.0.2-0, a "Check status now" button was added to the UI,
allowing for the status of pub tasks to be checked on demand.  However, this
feature suffered from a concurrency issue, which in rare cases could cause
post-push tasks of completed push jobs to be executed more than once.

This has been fixed, allowing the feature to be safely used.
