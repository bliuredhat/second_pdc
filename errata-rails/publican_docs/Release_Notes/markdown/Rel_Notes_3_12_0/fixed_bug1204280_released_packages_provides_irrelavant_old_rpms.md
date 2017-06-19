### Fixed incorrect released package lists in some cases for layered products

The base Channel/CDN repository file list provided old packages for layered products
that were not needed by every TPS job. A TPS job could fail incorrectly if the base
Channel/CDN repository contains old packages that do not match the new packages.

This had been fixed by grouping the old packages that are found in base Channels/CDN
repositories into their sub Channels/CDN repositories respectively which will prevent
all TPS jobs from fetching irrelevant data from the base Channels/CDN repositories.

For more details, please read the [comment](https://bugzilla.redhat.com/show_bug.cgi?id=1204280#c22) in
[bug 1204280](https://bugzilla.redhat.com/show_bug.cgi?id=1204280).
