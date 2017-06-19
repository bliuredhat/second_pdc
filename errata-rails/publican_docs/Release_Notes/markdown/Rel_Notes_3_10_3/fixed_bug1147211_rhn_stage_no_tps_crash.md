### Fixed a crash on RHN or CDN Stage push for advisories without TPS

After an RHN or CDN Stage push completes, Errata Tool attempts to
reschedule relevant TPS jobs.  It incorrectly attempted to do the
rescheduling in some cases even if the advisory does not use TPS.

In particular, a crash would occur after attempting a staging push
of an advisory with only non-RPM files.

This has been fixed; TPS rescheduling is now skipped as expected for
advisories which don't use TPS.
