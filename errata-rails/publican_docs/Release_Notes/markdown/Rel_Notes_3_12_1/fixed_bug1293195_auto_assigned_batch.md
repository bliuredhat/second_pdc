### Fix automatic batch assignment after advisory batch cleared

New advisories for releases that are configured for batching are automatically
assigned to the next available batch for the release.

This change fixes a problem that caused an advisory to be automatically assigned
to a batch, if the advisory had previously been removed from a batch.
