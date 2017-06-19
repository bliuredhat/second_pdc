### Don't move advisory to PUSH_READY if rel-eng ticket wasn't filed

For async releases, advisories in REL_PREP are automatically transitioned
to PUSH_READY when their release date arrives.  This transition includes
automatically filing an RT ticket for rel-eng to push the advisory.

Previously, if filing the RT ticket failed for any reason, the advisory
would be moved to PUSH_READY with a comment asking for the RT ticket to
be filed manually. In practice, that was often missed, causing advisories
to stall in PUSH_READY.

This has been changed so that advisories will not be moved to PUSH_READY
unless the rel-eng RT ticket can be filed successfully.

For more information, please see
[Bug 1080406](https://bugzilla.redhat.com/show_bug.cgi?id=1080406).
