### Added an API to refresh Bugzilla bugs

An API has been added to Errata Tool to trigger a refresh of Errata
Tool's copy of Bugzilla bugs.  This is an API equivalent of
[the Sync Bug List UI](https://errata.devel.redhat.com/bugs/sync_bug_list)
(although unlike that UI, it does not currently support JIRA issues).

This API may be used to ensure that Errata Tool knows about the latest
status of a bug.  It's particularly useful for scripts which create or
update Bugzilla bugs and then attach those bugs to advisories.

This API is documented
[in the Developer Guide](https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-post-apiv1bugrefresh).
