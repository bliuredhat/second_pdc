### Fixed RPMDiff tests unexpectedly bypassed

Previous versions of Errata Tool allowed users to bypass RPMDiff
testing on an advisory if RPMDiff runs weren't currently scheduled.
This could occur even if RPMDiff was configured to be compulsory for
the advisory's product.

This has been fixed by enforcing the following conditions before
RPMDiff is considered passed:

* An advisory (except text-only) must have at least one RPMDiff run.
* Every active brew build added to the advisory must have an RPMDiff run.
* All RPMDiff runs must be finished.

Errata Tool also now warns users about errors which prevent the
scheduling of RPMDiff runs.  Previously, these errors were logged but
not displayed.

