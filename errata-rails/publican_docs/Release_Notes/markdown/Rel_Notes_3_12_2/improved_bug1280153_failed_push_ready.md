### After failed push, move advisories to PUSH_READY, not REL_PREP

[Bug 1184468](https://bugzilla.redhat.com/1184468) changed the error handling
for failed RHSA push jobs, to move the advisories to PUSH_READY state instead
of REL_PREP.

This change extends this to cover all advisories.
