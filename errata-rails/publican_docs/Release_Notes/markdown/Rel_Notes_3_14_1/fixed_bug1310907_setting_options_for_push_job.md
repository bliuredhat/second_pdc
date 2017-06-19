### Fix inconsistent handling of push files and metadata between stage and live push

When doing pushes, Errata Tool needs to explicitly set `push_files` and
`push_metadata` to false if they are not set.

This was done correctly for live pushes, but not for stage pushes. This has
been fixed in this release of Errata Tool.
