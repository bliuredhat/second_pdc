### Add all_errata to show build API

The API `api/v1/build` has been updated to include "all_errata" in
the response. Any advisories (except those which are DROPPED\_NO\_SHIP)
that the build has been added to will be listed in the response.

This change is required by the MetaXOR project.
