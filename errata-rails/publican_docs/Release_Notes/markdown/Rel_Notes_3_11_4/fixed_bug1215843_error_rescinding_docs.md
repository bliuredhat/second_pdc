### Fix error when editing an advisory with approved docs

Errata Tool will rescind the approved docs automatically when updating
bugs or Jira issues of an advisory. If the user who is performing the
update doesn't have docs approval permission, then a permission error
was incorrectly raised.

This is now fixed. The logic related to rescinding the docs approval is fixed
and the permission check is correctly skipped if the docs rescinding action is
triggered automatically by the system.
