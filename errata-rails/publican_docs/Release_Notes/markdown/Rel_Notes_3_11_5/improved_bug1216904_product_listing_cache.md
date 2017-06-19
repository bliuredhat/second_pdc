### Enable product listing cache to be cleared

This change enables Release Engineering users to clear a product
listing cache for a release/build when it differs from the listings
in Brew. This is necessary if the listings in Brew change after
being loaded into Errata Tool.

Clearing the cache does not immediately update the listings, as
additional actions may be required. These can be triggered by
reloading files for affected errata.

The Product Listings page logic is updated to compare cached listings
against Brew. If there is a mismatch, allow the cached listing to be
displayed and optionally cleared.

The following screen shots show an example where the cached listings are
different to the current listings in ComposeDB.

[![View current listing](images/3.11.5/clearcache1.png)](images/3.11.5/clearcache1.png)

[![View current cached listing](images/3.11.5/clearcache2.png)](images/3.11.5/clearcache2.png)
[![Clear the cached listing](images/3.11.5/clearcache3.png)](images/3.11.5/clearcache3.png)
