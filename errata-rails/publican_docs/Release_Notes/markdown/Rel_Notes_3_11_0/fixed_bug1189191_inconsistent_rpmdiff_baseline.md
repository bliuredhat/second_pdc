### Fixed inconsistent RPMDiff scheduling for some advisories

In previous versions of Errata Tool, the RPMDiff scheduling algorithm
would give unstable results for certain errata.  In advisories
affected by this problem, the version of a package chosen as the
baseline for an RPMDiff test was unpredictable; it would sometimes use
a previous successful test on the advisory as a baseline, and
sometimes not.

Advisories having one build added to multiple product versions (such
as RHSCL advisories) were particularly likely to hit this problem.

This has been fixed by a change to the scheduler.  In cases where
there are multiple possibilities for scheduling a new RPMDiff run, the
scheduler now chooses the run with the newest baseline (if possible),
and always chooses the run in a stable manner.

Please note that only RPMDiff runs scheduled after this release will
benefit from the scheduler improvements.  For already existing
advisories affected by this bug, "Reschedule All RPMDiff Runs" may be
used to resolve inconsistencies in the scheduling.  (Rescheduling a
single run is insufficient.)

As a part of this change, RPMDiff runs on an advisory may now
sometimes be automatically rescheduled if the baseline for a test has
changed.
