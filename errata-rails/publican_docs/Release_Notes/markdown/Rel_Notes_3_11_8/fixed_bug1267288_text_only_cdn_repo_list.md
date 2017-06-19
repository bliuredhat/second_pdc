### Fix CDN repos for text-only errata not passed to pub

In previous versions of Errata Tool, while pushing a text-only CDN-only
advisory, the configured repo list for the advisory would not be exposed to pub
and would thus be effectively ignored for the push.  This resulted in errata not
being associated with the expected products in Customer Portal.

This has been fixed.  The text-only repo list is now exposed to pub, as
expected.  (There is also a
[related fix in pub](https://projects.engineering.redhat.com/browse/RCMPROJ-4831)).
