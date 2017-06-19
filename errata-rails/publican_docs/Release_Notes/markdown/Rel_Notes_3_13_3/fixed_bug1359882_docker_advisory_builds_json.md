### Fix advisory builds JSON output for docker builds

The `advisory/id/builds.json` API has been fixed so it works with Docker
advisories, in addition to RPM advisories. This API is used by the
`move-pushed-erratum` RCM script, which updates tags in Brew post-release.
