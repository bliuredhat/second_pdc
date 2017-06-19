### Fixed misleading "RPMDiff Complete" message for advisories that don't require RPMDiff

In earlier versions of Errata Tool, message "RPMDiff Complete" is shown
incorrectly whether RPMDiff is required or not on the advisory transition.

This has been fixed in the current version of Errata Tool. The more accurate
message "RPMDiff is not required" is shown when RPMDiff is not required for the
advisory.

[![RPMDiff not required](images/3.10.3/rpmdiff-not-required.png)](images/3.10.3/rpmdiff-not-required.png)
