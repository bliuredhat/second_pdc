### Fixed advisory stuck in IN_PUSH when push jobs fail

Previously, an advisory could remain in IN_PUSH state when a push job
failed or was cancelled by a user.  In particular, advisories using
both RHN and CDN did not handle certain failure cases as expected.

This has been fixed; Errata Tool now reliably keeps an advisory in
IN_PUSH state while an RHN or CDN push is in progress, and moves the
advisory back to REL_PREP if either push has failed, but only after
both push jobs have completed.
