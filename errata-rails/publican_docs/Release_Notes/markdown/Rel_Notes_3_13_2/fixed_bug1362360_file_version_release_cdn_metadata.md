### Provide correct RPM version and release in CDN metadata

Previously, Errata Tool returned the Brew build version and release as
the version and release for individual RPMs in the response to the
`get_advisory_cdn_metadata` API. Although the RPM and build values would
match most of the time, sometimes they did not.

This fix improves the reliability of the metadata in Pulp/CDN.
