### New API for pushing multiple errata

Errata Tool has gained
[a new API](/developer-guide/api-http-api.html#api-post-apiv1push)
for triggering the push of multiple errata in a single request.

Compared to the
[existing API](/developer-guide/api-http-api.html#api-post-apiv1erratumidpush)
for pushing a single advisory, this new API gives two significant benefits:

* It supports more directly the Release Engineering use-cases of pushing an
  entire release or batch. Thus, it will help us to retire some legacy scripts
  currently used for these cases (see
  [bug 1112494](https://bugzilla.redhat.com/1112494)).

* It supports pushing multiple errata from a single pub task for improved
  performance, as described elsewhere in the release notes
  ([bug 1300153](https://bugzilla.redhat.com/1300153)).
