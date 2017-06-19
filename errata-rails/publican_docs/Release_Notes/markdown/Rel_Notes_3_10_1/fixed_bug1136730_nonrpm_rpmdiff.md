### Fixed advisories with non-RPM files blocked on RPMDiff

In Errata Tool 3.10.0 the initial support for adding non-RPM files to
advisories was released. Advisories with only non-RPM files were being
incorrectly blocked due to the fact that they had not completed RPMDiff, which
is incorrect behaviour since RPMDiff is applicable only to RPMs.

This has been fixed in Errata Tool 3.10.1.
