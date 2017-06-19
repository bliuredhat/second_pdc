### Fixed job trackers page not paginated

In previous versions of Errata Tool, the
[job trackers page](https://errata.devel.redhat.com/job_trackers) would display
a table with one row per background job tracker in the system, with no
pagination.  This could lead to performance issues when loading the page, since
there are thousands of job trackers.

This UI has now been paginated to resolve the performance issues.  Additionally,
the most recent job trackers are now listed first, making it easier to find the
relevant data on this page.
