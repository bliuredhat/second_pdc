### Newest build should only be added to an advisory

Previously, adding a new build to an advisory automatically removed the
corresponding old build and the files, but it would fail when the old build
contained multiple files with different Brew archive types.

Also, adding multiple builds with different versions of the same package at the
same time was incorrectly permitted.

This has been fixed. An advisory will always keep the newest build and remove
all the files with old version regardless of the Brew archive types.
