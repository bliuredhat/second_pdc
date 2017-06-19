### Staging pushes block transition from QE to REL_PREP

Previously, an advisory could be moved from QE to REL_PREP states
even if a required staging push had not completed successfully.

This has changed. Now, all advisories that support staging push
targets will only be allowed to move from QE to REL_PREP if the
staging push jobs have completed successfully.
