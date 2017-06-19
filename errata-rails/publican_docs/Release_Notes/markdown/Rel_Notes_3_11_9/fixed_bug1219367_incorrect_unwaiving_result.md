### Fixed error handling when attempting to waive or unwaive old RPMDiff results

Previously, a failure occurring during waiving or unwaiving would not be handled
properly, resulting in an incorrect score being stored in the RPMDiff result.

This has now been fixed. If an exception occurs during either waiving or
unwaiving, an error message will be shown and no change will be made.
