### Fixed CCAT not displayed for errata externally pushed to CDN

Errata Tool recently gained support for the display of CDN Content Availability Testing
([CCAT](https://mojo.redhat.com/docs/DOC-1051013)) results.

Previously, these results would be displayed only for errata eligible to be pushed by
Errata Tool to CDN. However, CCAT also applies to errata pushed to CDN externally from
Errata Tool. For example, this currently occurs for RHEL 6 errata.

The CCAT display has now been improved so that CCAT results will be displayed whenever
they're available, regardless of whether the tested advisory was pushed to CDN by Errata
Tool.

(This bug fix was deployed to production prior to the 3.12.2 release, in
Errata Tool 3.12.1.2)
