### CVE problems are no longer blocking

Potential issues relating to CVEs (such as a mismatch between the advisory CVE
list and the attached bugs) no longer block updates to an RHSA. Previously, any
such issues would prevent the affected advisory from being updated by any user
without the "secalert" role.

In Errata Tool 3.11.0, a
[Product Security Approval](https://bugzilla.redhat.com/show_bug.cgi?id=1167631)
step was introduced to the RHSA workflow.  Reviewing and correcting CVE problems
is now performed by the Product Security Team during this step, so it's
unnecessary to block on CVE problems elsewhere.

This change improves the usability of RHSA for non-secalert Errata Tool users.
