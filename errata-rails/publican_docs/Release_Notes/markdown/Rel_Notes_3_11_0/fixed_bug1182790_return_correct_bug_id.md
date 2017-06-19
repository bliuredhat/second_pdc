### Fixed incorrect bug ID returned by get_advisory_cdn_metadata

Previously, the get_advisory_cdn_metadata XML-RPC API incorrectly
returned the advisory ID in a field which is supposed to contain
a bug ID.

This fix was earlier deployed in the Errata Tool 3.10.6.2 hotfix
release.
