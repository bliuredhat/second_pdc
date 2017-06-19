### Validate versions when manually adding released packages

Errata Tool maintains a list of released packages which are used for
scheduling TPS, RPMDiff, and Covscan comparisons. This list is updated
automatically when an advisory is shipped, but it's also possible to add
released packages manually.

Previously Errata Tool didn't check the version of the packages when they were
added manually, so it was easy for a user to incorrectly add NVRs that were
much older than the current released NVRs.

This is fixed in Errata Tool 3.11.4. If a user tries to add released packages
that are older than the existing released packages, the UI will show a warning
as well as provide some advice to the user. The user can decide to proceed
anyway, (which may be necessary in some rare cases), or cancel the request.
