### Integrated CDN Content Availability Testing (CCAT)

Errata Tool now stores and displays CDN Content Availability Testing (CCAT)
results.

[![CCAT tab](images/3.12.1/ccat_tab.png)](images/3.12.1/ccat_tab.png)

CCAT verifies that the content for an advisory can be successfully retrieved
from CDN.  It ensures that any problems preventing customers from accessing an
advisory will be promptly detected.

CCAT applies to any advisory pushing at least one RPM to CDN.  It is triggered
automatically after an advisory has been shipped (SHIPPED_LIVE status).  The
results are informational only and do not block any actions on the advisory.
This may change in a future release of Errata Tool.

For general information regarding CCAT, see
[Errata Tool: Content Testing](https://mojo.redhat.com/docs/DOC-1051013).  See
also [bug 1182269](https://bugzilla.redhat.com/1182269) for information
regarding Errata Tool's integration with CCAT.
