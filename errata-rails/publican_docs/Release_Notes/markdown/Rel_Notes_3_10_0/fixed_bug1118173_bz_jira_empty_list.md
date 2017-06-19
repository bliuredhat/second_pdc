### Fixed invalid links to bug/issue lists for an advisory with no bugs/issues

If an advisory had no associated Bugzilla bugs or JIRA issues,
the advisory details page would display an invalid link to
a Bugzilla bug list or JIRA issue list.

This has been fixed by only presenting a link to the bug/issue list
if the advisory contains at least one bug/issue reference.

Other links which don't make sense when there are 0 bugs/issues were
also hidden, making the UI cleaner.

[![buglinks](images/3.10.0/buglinks.png)](images/3.10.0/buglinks.png)

For more information, see
[Bug 1118173](https://bugzilla.redhat.com/show_bug.cgi?id=1118173).
