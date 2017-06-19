### Fixed incorrect pre-push embargoed bugs warning

Previously a warning message about embargoed bugs was shown when any bug filed
on the advisory, or blocked by bugs filed on the advisory was a private
security response bug. This caused the warning to be present for all RHSAs as
blocked private bugs exist for all RHSAs.

A side-effect of this bug was that partners were incorrectly prevented from
receiving notifications about security advisories. (See related bug
[1216253](https://bugzilla.redhat.com/show_bug.cgi?id=1216253).)

This has been fixed by performing the embargoed bug checks only on bugs
belonging to the 'vulnerability' component.
