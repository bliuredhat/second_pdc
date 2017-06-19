### Fixed CDN push incorrectly blocked

On earlier versions of Errata Tool, for certain advisories which support both
RHN and CDN pushes, attempting to push to RHN and CDN together would
incorrectly prevent the CDN push with the error message:

    Creating push job failed: Validation failed: Advisory has not been
    shipped to rhn live channels yet.

This has been fixed.
