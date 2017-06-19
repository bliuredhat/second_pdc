### Fix incorrect available releases list when cloning an advisory

When using the 'manual create' form to clone an advisory, the list of
available releases in the release drop-down was not correctly updated. This
caused releases that didn't match the advisory's product to be shown.

This has been fixed; the release list now shows currently active releases for
the advisory's product when an advisory is being cloned.
