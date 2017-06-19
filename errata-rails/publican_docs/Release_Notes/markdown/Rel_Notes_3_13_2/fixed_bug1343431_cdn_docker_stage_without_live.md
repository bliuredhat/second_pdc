### CDN docker stage works even if CDN docker target is disabled

Previously, Errata Tool would prevent docker advisories from being
pushed to staging, if the CDN docker live push target was disabled.

This has been fixed; it is now possible to push to CDN docker stage
even if the live CDN docker push target is disabled.
