### Replaced cron jobs with background jobs

A few tasks which were previously executed by cron jobs on the Errata
Tool server have been replaced with background jobs, using the same
job queue mechanism used for other tasks in Errata Tool.

This improves maintainability and visibility of the jobs and reduces
the load on the server.
