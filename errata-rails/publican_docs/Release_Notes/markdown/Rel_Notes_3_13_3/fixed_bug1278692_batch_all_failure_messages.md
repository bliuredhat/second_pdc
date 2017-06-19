### Show all batch failure conditions for transition to PUSH_READY

Previously, Errata Tool only showed one failure message related to batches
if an advisory could not transition to PUSH_READY due to batch problems,
such as future release date or other blocking advisories.

This has been fixed. Now all unsatisfied conditions will be returned in the
failure message.
