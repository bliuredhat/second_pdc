### Fixed problem preventing adding kernel builds to advisories

When adding a brew build to an advisory, Errata Tool does a check to confirm
that the RPMs in the build aren't older than RPMs already released to
customers.

Currently ARM 64 kernels are built in their own separate kernel-aarch64
package, and since the released ARM 64 kernel-aarch64 build is a newer version
than current unreleased standard kernel builds, Errata Tool was reporting that
the released kernel-aarch64 build had newer versions of the files, which
prevented build from being added to an advisory.

This has been fixed. Errata Tool will no longer consider the kernel-aarch64
file versions when adding kernel builds to an advisory.

(This bug fix was deployed to production prior to the 3.12.2 release, in
Errata Tool 3.12.1.2)
