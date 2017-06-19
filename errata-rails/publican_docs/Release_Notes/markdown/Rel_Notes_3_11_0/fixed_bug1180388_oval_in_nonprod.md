### Fixed OVAL pushes triggered from non-production Errata Tool

A configuration problem allowed production OVAL pushes to be performed
from test and development Errata Tool environments.  This has been
fixed to ensure that production OVAL pushes only occur from the
production Errata Tool environment.
