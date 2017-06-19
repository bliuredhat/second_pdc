### Close Bugzilla bugs and JIRA issues following Docker push

Previously, Errata Tool would fail to close Bugzilla bugs and JIRA issues
assigned to a Docker advisory after pushing the advisory to CDN, if the
CDN push job completed before the CDN Docker push job.

This has been fixed; bugs and issues will be closed following successful
completion of CDN push, even if the Docker push has not yet completed.
