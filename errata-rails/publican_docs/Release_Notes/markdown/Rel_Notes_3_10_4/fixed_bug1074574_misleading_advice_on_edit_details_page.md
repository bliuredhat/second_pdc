### Fixed misleading advice related to changing an advisory's release type

It's not possible to move an advisory to a Y-stream release after it has been
created due to the different approved component rules for addings bugs. For
this reason, if an advisory is created with the incorrect release type, it
needs to be dropped and recreated.

Since unprivileged users are not permitted to drop advisories, the advice to
"drop the advisory and recreate" it was confusing. This has been rectified in
Errata Tool 3.10.4. The explanation text now describes how non-admin users
should request that the advisory is dropped if it needs to be recreated in a
Y-stream release.
