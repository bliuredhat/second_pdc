### Fix bug dependencies sync issue

Previously, bugs were not properly syncing their dependencies when changed in
Bugzilla. Especially, when all the dependencies are removed from parent bug, it
would fail to sync with Errata Tool.

This has been fixed in this release of Errata Tool.
