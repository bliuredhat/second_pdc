### Fixed redundant TPS/DistQA jobs

Previously, TPS jobs for each sub RHN Channel/CDN Repository were scheduled
separately. This was unnecessarily causing several stable systems to pick up
different jobs which were effectively running exactly the same test.

In Errata Tool 3.10.2 this is resolved by grouping all the sub RHN
Channels/CDN Repositories with the same base RHN Channel/CDN Repository into a
single unique TPS Job, thus preventing the stable systems from running duplicate
tests.
