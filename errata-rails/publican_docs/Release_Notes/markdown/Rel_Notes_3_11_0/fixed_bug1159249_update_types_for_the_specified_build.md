### Fixed inconsistent behavior using API to change Brew file types

When using non-RPM files on an advisory, attempting to change the
selected file types on an advisory via the add_builds API could give
inconsistent results.

This has been fixed by not allowing the file types to be changed via
add_builds.  The file types may be reselected using the UI, or by
removing and re-adding the build with the API.
