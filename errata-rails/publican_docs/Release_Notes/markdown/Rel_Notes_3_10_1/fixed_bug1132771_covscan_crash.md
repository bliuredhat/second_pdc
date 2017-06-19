### Fixed a crash when Covscan's API reports an error

While Errata Tool was attempting to schedule a Covscan test run,
errors returned by Covscan's API were not handled correctly.  In some
cases, this resulted in a 500 internal server error when attempting to
add builds to an advisory.

This has been fixed.  Errors returned by Covscan's XML-RPC API are now
correctly handled and displayed in the Errata Tool UI as expected.
