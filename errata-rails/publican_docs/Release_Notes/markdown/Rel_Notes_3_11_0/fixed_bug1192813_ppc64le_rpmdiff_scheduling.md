### Fixed incorrect RPMDiff scheduling for ppc64le builds

For RHEL 7.1 advisories, most advisories are expected to contain
related non-ppc64le and ppc64le builds (in RHEL-7.1.Z and
RHEL-LE-7.1.Z product versions respectively).

In certain cases, Errata Tool would schedule RPMDiff runs incorrectly
for these builds.  In particular, if the advisory previously had a
passed (or waived) RPMDiff run for a ppc64le RPM, adding a non-ppc64le
RPM may have scheduled a comparison between the non-ppc64le and
ppc64le RPMs (or vice-versa).

This has been fixed.  Errata Tool now reliably considers RHEL-7.1.Z
and RHEL-LE-7.1.Z separately during RPMDiff scheduling.

This fix was earlier deployed in the Errata Tool 3.10.6.4 hotfix
release.
