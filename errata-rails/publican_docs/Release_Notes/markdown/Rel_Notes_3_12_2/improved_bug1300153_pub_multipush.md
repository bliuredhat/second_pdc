### Use pub multi-advisory push for improved performance

Recently, a feature was added to pub allowing it to push multiple errata to CDN
(pulp) in a single task. This eliminates some unnecessary work, resulting in
overall improved throughput when pushing multiple errata.

Errata Tool is now able to make use of this pub feature.  It will automatically
be used when the
[new push API](/developer-guide/api-http-api.html#api-post-apiv1push) is used to
push a release or batch to CDN. When using the API or UI to push a single
advisory, behavior is unchanged.

(Note that this feature is controlled by a server setting, which defaults to
disabled. The feature will be enabled after the appropriate version of pub is
deployed to production.)
