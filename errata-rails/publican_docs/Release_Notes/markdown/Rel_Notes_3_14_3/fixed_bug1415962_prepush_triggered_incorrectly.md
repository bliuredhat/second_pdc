### Pre-push only triggered on REL_PREP

Pre-push jobs were triggered in workflow states which were too early or too
late, resulting in errors with content delivery causing much manual work to
correct.

The pre-push now happens only after the advisory has transitioned to REL-PREP.
