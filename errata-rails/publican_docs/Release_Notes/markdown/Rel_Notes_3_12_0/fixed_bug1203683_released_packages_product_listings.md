### Fixed irrelevant packages appearing in TPS file lists

A problem in Errata Tool's released packages APIs (used during TPS testing) has
been fixed.

Previously, these APIs could incorrectly return irrelevant subpackages for an
advisory. This could happen if an advisory contained a build with subpackages
which have previously been shipped for a related product version, but would not
be shipped for this advisory due to product listings. In some cases, this would
result in incorrectly failed TPS tests.

This has been fixed by adjusting these APIs to consider only those RPMs present
in product listings when querying for released packages.

This fix also resolves another closely related released package accuracy issue,
[bug 1271462](https://bugzilla.redhat.com/show_bug.cgi?id=1271462).

Note that this fix was previously shipped in Errata Tool 3.11.7.1, but was
reverted and revised after performance issues were encountered.
