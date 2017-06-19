### Fixed get_released_channel_packages timeouts

Some changes introduced in Errata Tool 3.9 caused a regression which was
resulting in timeouts while providing a list of released packages for
advisories with a large number of builds.

The changes were part of making sure that Errata Tool always used the latest
package available in a channel or repo. (See
[Bug 1074104](https://bugzilla.redhat.com/show_bug.cgi?id=1074104)).

Because of the extra queries being performed to find the latest packages the
response was much slower than before and hence would time out for advisories
with a large number of builds.

This was fixed by adding an index to the name column in the brew_rpms table,
and modifying some SQL queries to ensure that the index could be properly
utilised by MySQL.

Since this was preventing TPS tests from completing for advisories in some
cases, the fix was shipped as soon as it was ready in Errata Tool 3.9.2-0 (on
July 21).

For more information see
[Bug 1120438](https://bugzilla.redhat.com/show_bug.cgi?id=1120438).
