### Do not replan batched advisories which are in REL_PREP

Previously, Errata Tool required all advisories in a batch to be in PUSH_READY
state, before any of them are pushed. Any advisories in NEW\_FILES, ON\_QA or
REL_PREP were moved to the next batch when an advisory from the batch is pushed.

This has been changed. Now, only advisories in NEW\_FILES or ON\_QA state will be
automatically moved to the next batch when another advisory in the batch is
pushed. REL_PREP advisories will remain in the batch.
