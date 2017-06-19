### Copying RHSA advisories without secalert role will also copy CVE names

In Errata Tool 3.10.1 the ability for non-privileged users to create low impact
RHSAs was added.

When a non-privileged user (i.e. a user without the `secalert` role)
created a new RHSA by cloning an existing RHSA, the cloning process would not
preserve the CVE names from the cloned advisory.

This behavior was inconsistent with the behaviour for users with the `secalert`
role and hence has been modified so that now the CVE names are cloned also.
