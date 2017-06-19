### Fixed TPS jobs not rescheduled when multi product support is toggled

Previously, when an advisory was moved from QE to NEW_FILES and back to QE,
TPS jobs would only be rescheduled if builds had been added to or removed
from the advisory since the previous TPS scheduling.

This meant that changes to any other settings affecting TPS scheduling
were ignored until a user manually invoked the "Reschedule All" or
"Check For Missing" actions for the TPS jobs.  These settings included
whether multiple product support was enabled for the advisory, and
the configured channels for the advisory's product(s).

This has been fixed.  Errata Tool now always checks if TPS jobs should
be added or removed when moving an advisory to QE state.  (It still
won't restart existing TPS jobs if the builds on an advisory are
unchanged.)

For more information, please see
[Bug 1076284](https://bugzilla.redhat.com/show_bug.cgi?id=1076284).
