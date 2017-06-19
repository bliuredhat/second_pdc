### Fixed conflicting Brew RPM and non-RPM files

A problem in Errata Tool's schema could prevent the usage of some
non-RPM files (archives) in Errata Tool.  Specifically, archives with
the same ID as an RPM already known to Errata Tool would silently fail
to be imported.

This has been fixed by an update to the schema ensuring that Brew RPMs
and archives using the same ID do not conflict with each other.
