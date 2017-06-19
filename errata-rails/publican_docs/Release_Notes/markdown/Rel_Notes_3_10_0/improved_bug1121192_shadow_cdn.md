### Support shadow push for CDN

When performing a CDN push, it's now possible to select a "Push to shadow repos"
option.

This option works similarly to the "Push to shadow channels" option for RHN.

[![shadowpush](images/3.10.0/shadowpush.png)](images/3.10.0/shadowpush.png)

At the time of writing, pub had not yet been updated to understand the shadow
option for CDN pushes.  Shadow pushes for CDN will be disabled in Errata Tool
until pub has been updated.

For more information, please see
[Bug 1121192](https://bugzilla.redhat.com/show_bug.cgi?id=1121192).
