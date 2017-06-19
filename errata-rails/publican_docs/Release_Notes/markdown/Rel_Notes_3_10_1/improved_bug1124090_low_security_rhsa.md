### Enable unprivileged users to create low-impact RHSA

On request from the Product Security Team (PST), some changes were
made to the restrictions applied to security advisories.

It is now possible for users outside of the PST (users without the
'secalert' role in Errata Tool) to create RHSA if the following
criteria is satisfied:

* The "Security Impact" is Low.
* No embargo date is set.
* The "CVE Names" field is used correctly (all references in "CVE
  Names" also exist in the advisory description and in the summary of
  a referenced bug).

As a part of this improvement, long standing bugs which incorrectly
allowed unprivileged users to modify certain fields on security
advisories have also been fixed.

For more information, please see
[bug 1124090](https://bugzilla.redhat.com/show_bug.cgi?id=1124090),
[bug 1135360](https://bugzilla.redhat.com/show_bug.cgi?id=1135360) and
[bug 990003](https://bugzilla.redhat.com/show_bug.cgi?id=990003).
