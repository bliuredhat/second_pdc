### New JSON API to fetch information about releases

Previously it was not possible to fetch the list of releases in Errata Tool
(other than scraping it from HTML), and the API for fetching information about
a single release was undocumented. A new `releases` API has been added to allow
external systems to query information about releases in a supported and
documented way.

For details please see [Releases API][ReleasesApi].

[ReleasesApi]: https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-releases
