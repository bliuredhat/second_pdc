### Always ignore duplicate filed issue check for RHSA

Previously, all JIRA issue validity checks were ignored for RHSA - only
for secalert users. For non-secalert users, the checks would be applied,
and due to the way RHSA are used, this check in particular prevents
[Bug 1124090](https://bugzilla.redhat.com/show_bug.cgi?id=1124090) from being useful.

This has been fixed by making Errata Tool always skip the check for RHSA,
regardless of the user's roles.
