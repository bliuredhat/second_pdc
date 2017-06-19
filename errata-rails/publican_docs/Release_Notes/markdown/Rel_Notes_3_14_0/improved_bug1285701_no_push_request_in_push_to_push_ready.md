### Push request message not generated on return to PUSH_READY

Previously, Errata Tool would generate a comment and email when an advisory
for an async release reached PUSH_READY state. This was also the case if
the advisory moved from IN_PUSH back to PUSH_READY.

This has been changed, so that these notifications are not generated when
moving from IN_PUSH (but are still generated when moving from REL_PREP to
PUSH_READY).
