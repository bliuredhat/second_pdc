### Show correct links to non-production Brew builds

Previously, all links to Brew builds were hard coded to Brew production. With
the newly added support for Errata Tool stage to access Brew stage,
([Bug 1316182](https://bugzilla.redhat.com/show_bug.cgi?id=1316182)), these
links became incorrect as they point at Brew production instead of staging.

This has been fixed and Errata Tool now points Brew build links to the correct
Brew instance.

In addition to this, links to Brew production server have been updated to
reflect its recent migration to PDI.
