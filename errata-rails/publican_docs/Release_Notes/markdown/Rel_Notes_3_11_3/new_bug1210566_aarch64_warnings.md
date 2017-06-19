### Added ARM Server 64-bit build awareness for RHEL-7.1

In RHEL-7.1, ARM Server 64-bit builds have their own separate dist tag in
Brew. Hence RHEL-7.1.Z advisories need to have '.aa7a' builds added in
addition to the regular '.el7' builds.

Similar to the recently added
[support for PPC64LE](https://errata.devel.redhat.com/release-notes/rel-notes-3-11-0-release-notes-for-version-3.11.0.html#rel-notes-3-11-0-added-ppc64le-build-awareness-for-rhel-7.1),
Errata Tool will automatically check for corresponding aarch64 builds when a
build is added to an RHEL-7.1.Z advisory. It will also show a notice with
links to further information wherever aarch64 builds may be required.

This functionality will be shipped initially disabled and won't be switched on
until RHELSA is generally available.
