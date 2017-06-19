### Fixed RHN links incorrectly used on Security Response bugs

In Errata Tool 3.10.2, comments posted on Bugzilla bugs and JIRA
issues were updated to link to RHN or CDN accordingly, depending on
the push targets used for an advisory. Previously, RHN links were
always used. See
[bug 1145368](https://bugzilla.redhat.com/show_bug.cgi?id=1145368).

One instance of a hardcoded link to RHN was missed: the comment posted
on Security Response bugs when an advisory is shipped.  This has now
been fixed, and CDN links are used when appropriate with Security
Response bugs.
