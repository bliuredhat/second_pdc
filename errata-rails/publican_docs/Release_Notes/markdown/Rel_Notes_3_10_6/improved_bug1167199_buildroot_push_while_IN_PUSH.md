### Prevent usage of "Push to Buildroot" while advisory is IN_PUSH

The recently added Push to Buildroot feature, which could previously
be used for any active Errata, has been made slightly more strict.  It
is no longer allowed to request a push to buildroot while an RHN/CDN
push for the advisory is in progress.
