### Reschedule TPS runs when an advisory's files are reloaded

Errata Tool will automatically reschedule TPS when an advisory moves from
NEW_FILES to QE if any builds have been added or removed. However if a build's
files are reloaded, without any other changes, the TPS tests were not being
rescheduled. Existing TPS tests run prior to the files being reloaded would
appear as passed, which could potentially allow TPS problems to remain
undetected.

Additionally, when reloading all files for an advisory, (a task that is run as
a background job), the background job was not properly adding a comment to the
advisory to indicate the files had been reloaded.

Both of these issues have been fixed in Errata Tool 3.10.5.
