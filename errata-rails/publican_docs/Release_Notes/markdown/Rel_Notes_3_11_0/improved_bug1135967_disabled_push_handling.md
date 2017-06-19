### Improved behavior when push targets are disabled for all packages in advisory

Errata Tool allows RHN and CDN push targets to be toggled per package
within a configured variant.

Previously, if a push target was disabled for all packages in an
advisory, it was still permitted (and required) to do an empty push
for that target.

This has been improved.  Errata Tool now detects if there are no
packages applicable to a push target and allows that target to be
skipped.
