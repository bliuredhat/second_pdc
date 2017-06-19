### Improved safety of Errata Tool upgrade procedure

Previously, the Errata Tool web service would remain running during all upgrades
to Errata Tool.  In some cases, requests received during an upgrade could
trigger internal server errors or other incorrect behavior.

To resolve this problem, Errata Tool will now enter "maintenance mode" during
the critical portion of upgrades (typically less than 1 minute, but may be
longer for complex releases).  All HTTP requests will be rejected with HTTP 503
Service Unavailable during this time.
