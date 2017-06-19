### Fixed errors assigning live IDs to errata during push

Previously, when pushing multiple errata at the same time, Errata Tool would
sometimes fail to generate an advisory's live ID with a "Duplicate entry" error.
Although this did not affect the integrity of the data, these errors would
result in failed push jobs, requiring pushes to be retried.

This bug was caused by a race condition, which has been fixed by introducing
appropriate locking.
