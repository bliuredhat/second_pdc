### Fixed bugs reverted unexpectedly while updating bug status

In some situations, Errata Tool would previously perform status changes to
bugs other than the changes selected by the user. This could unintentionally
revert status changes which had already completed and not yet reflected to
current window.

This has been improved so that only the bugs the user requests to update will
be updated.
