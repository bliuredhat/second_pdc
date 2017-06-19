### Update advisory batch if release is changed

Previously, if an advisory's release was changed, the batch would not
be updated.

This has been fixed. Now, if an advisory is changed to a release that
does not support batching, the advisory will not be assigned to a batch.
If an advisory is changed to a release that does support batching, it
will be assigned to the next available batch for that release.

See also:
[Bug 1311397](https://bugzilla.redhat.com/show_bug.cgi?id=1311397)
