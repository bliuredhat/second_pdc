### Add missing repo name to TPS JSON and XML outputs

In Errata Tool 3.9 the TPS changes related to supporting TPS on Pulp/CDN
introduced a new field called 'repo_name'. The new field was visible in the
web UI, but was not added to API data, available at
`/advisory/$errata_id/tps_jobs.json` and `/advisory/$errata_id/tps_jobs.xml`)

In ET 3.10.0 the missing field has been added.

For more information, please see
[Bug 1087399](https://bugzilla.redhat.com/show_bug.cgi?id=1087399).
