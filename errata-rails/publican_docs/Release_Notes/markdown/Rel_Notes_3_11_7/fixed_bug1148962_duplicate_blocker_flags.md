### Fixed duplicate blocker flags breaking ACL sync

Previously, the release creation form allowed users to add compulsory blocker
flags (such as devel_ack, qa_ack, pm_ack) to the blocker flags field along with
release specific blocker flags.  These flags are implied for quarterly updates.
Explicitly adding the flags would prevent synchronization of approved
components.

This has been fixed. Compulsory blocker flags are now stripped from the blocker
flags specified by the user, avoiding synchronization issues.
