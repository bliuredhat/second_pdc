### Improved error handling during Find New Builds

Errata Tool 3.10.6 introduced a new user interface for finding/adding
builds to an advisory, using a progress bar to display the progress of
the (sometimes slow) build fetching operations.

Previously, that UI did not usefully report fatal errors such as
incorrect product listings, attempting to add a not-yet-completed
build, and timeouts communicating with brew.  In all such cases, the
UI would display a generic failure message.

This has been improved.  If fetching builds repeatedly fails, the UI
will now display the specific builds and product versions which could
not be fetched, with the error message returned from brew (if
available).

![Find New Builds errors](images/3.11.0/find_new_builds_errors.png)

Some minor cosmetic issues relating to error handling in this UI have
also been resolved.

For more information, please see
[Bug 1183889](https://bugzilla.redhat.com/show_bug.cgi?id=1183889) and
[Bug 1179522](https://bugzilla.redhat.com/show_bug.cgi?id=1179522).
