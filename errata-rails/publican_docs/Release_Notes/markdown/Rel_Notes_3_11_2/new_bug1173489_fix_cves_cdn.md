### Added CDN support to Fix CVE Names

Errata Tool has a "Fix CVE Names" feature which may be used to change
the CVEs associated with an advisory, without requiring a full re-push
of the advisory.  Previously, this feature only worked for RHN Live.

This feature has been updated to add support for CDN / Customer
Portal.  Errata Tool will automatically fix CVEs for RHN and CDN
accordingly, depending on the push targets used for the updated
advisory.

This functionality also required related modifications to Pub. For details on
the Pub changes please see
[RCMPROJ-3281](https://projects.engineering.redhat.com/browse/RCMPROJ-3281).
