### Fixed ppc64le/aarch64 data incorrectly included in released packages

After shipping an advisory, Errata Tool stores the packages released from that
advisory for later use (by RPMDiff and TPS scheduling in particular).

Previously, RHEL 7 builds with ppc64le/aarch64 RPMs would incorrectly result in
released package records being created for these arches, even if there were no
active ppc64le/aarch64 repositories for the relevant RHEL release
(e.g. FAST7.2). This could cause RHEL 7.1 and 7.2 TPS jobs to give invalid
results.

This has been fixed so that released packages data more accurately reflects the
content pushed by an advisory.
