### JSON API to fetch details of RPMDiff runs and RPMDiff results

Previously it was not possible to fetch details of RPMDiff result in Errata
Tool.

- A new `RPMDiff Runs` API has been added to allow external systems to query
information about RPMDiff Runs in a supported and documented way.

  For details, please see [RPMDiff Runs API][RPMDiffRunsApi].

[RPMDiffRunsApi]:
https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-rpmdiff-runs

- A new `RPMDiff Results` API has been added to allow external systems to query
information about RPMDiff Results in a supported and documented way.

  For details, please see [RPMDiff Results API][RPMDiffResultsApi].

[RPMDiffResultsApi]:
https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-rpmdiff-results
