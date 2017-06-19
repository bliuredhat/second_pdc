### Replace getOrgChart with getGroup

Errata Tool regularly syncs data from OrgChart to update organization group
information for Errata Tool users.

In OrgChart 3.0, the `getOrgChart` XML-RPC method used by Errata Tool to do
that syncing was deprecated. In Errata Tool 3.10.2 the supported `getGroup`
method is used instead.

For more information see
[Bug 1136190](https://bugzilla.redhat.com/show_bug.cgi?id=1136190)
and the [OrgChart User Guide](https://docs.engineering.redhat.com/x/vpsEAQ).
