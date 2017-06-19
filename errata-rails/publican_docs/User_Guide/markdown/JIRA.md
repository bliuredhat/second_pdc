Errata & JBoss JIRA
===================

About JIRA
----------

JIRA is a flexible issue tracking tool, used for tracking bugs and other
types of issues.

At Red Hat, JBoss Enterprise Application Platform and other JBoss products
use the [JBoss Community JIRA](https://issues.jboss.org) for issue tracking.

Adding/removing JIRA issues to an advisory
---------------------------------

Errata Tool supports linking JBoss JIRA issues into an advisory.
An advisory may contain Bugzilla bugs only, JBoss JIRA issues only, or both.

To add JIRA issues to an advisory, add one or more JIRA issue keys into the
appropriate field under "Advisory Content", while creating or editing an
advisory:

[![jira_entry_form](images/jira/jira_entry_form.png)](images/jira/jira_entry_form.png)

Note that this field also accepts aliases for Bugzilla bugs.

In the case where a valid JIRA issue key is also a valid Bugzilla bug alias,
add a prefix of 'jira:' or 'bz:' to the identifier to disambiguate, such as: jira:MYBUG-123.

To remove JIRA issues, use the same form to remove the corresponding issue keys.

JIRA issues may also be added and removed using Errata Tool's API.
Please see [the Developer Guide](https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-apis)
for more information.

Viewing an advisory's JIRA issues
---------------------------------

Adding JIRA issues to an advisory causes the issues to be displayed in several places,
both in Errata Tool and in customer-facing systems.

Issues are displayed on the advisory's summary page, as in the following example:

[![jira_and_bugs](images/jira/jira_and_bugs.png)](images/jira/jira_and_bugs.png)

Issues are included in the advisory text, next to the list of Bugzilla bugs (if any):

    =====================================================================
                       Red Hat Security Advisory

    Synopsis:          Important: JBoss Enterprise Application Platform 5.2.0 security update
    Advisory ID:       RHSA-2013:0232-01
    Product:           Red Hat JBoss Enterprise Application Platform
    Advisory URL:      https://access.redhat.com/errata/RHSA-2013:0232
    Issue date:        2013-02-04
    CVE Names:         CVE-2012-5629
    =====================================================================

    1. Summary:

    An update for JBoss Enterprise Application Platform 5.2.0 which fixes one
    security issue is now available from the Red Hat Customer Portal.

    The Red Hat Security Response Team has rated this update as having
    important security impact. A Common Vulnerability Scoring System (CVSS)
    base score, which gives a detailed severity rating, is available from the
    CVE link in the References section.

    2. Description:

    JBoss Enterprise Application Platform is a platform for Java applications,
    which integrates the JBoss Application Server with JBoss Hibernate and
    JBoss Seam.

    When using LDAP authentication with the provided LDAP login modules
    (LdapLoginModule/LdapExtLoginModule), empty passwords were allowed by
    default. An attacker could use this flaw to bypass intended authentication
    by providing an empty password for a valid username, as the LDAP server may
    recognize this as an 'unauthenticated authentication' (RFC 4513). This
    update sets the allowEmptyPasswords option for the LDAP login modules to
    false if the option is not already configured. (CVE-2012-5629)

    Warning: Before applying this update, back up your existing JBoss
    Enterprise Application Platform installation (including all applications
    and configuration files).

    All users of JBoss Enterprise Application Platform 5.2.0 as provided from
    the Red Hat Customer Portal are advised to apply this update.

    3. Solution:

    The References section of this erratum contains a download link (you must
    log in to download the update). Before applying the update, back up your
    existing JBoss Enterprise Application Platform installation (including all
    applications and configuration files).

    The JBoss server process must be restarted for this update to take effect.

    4. Bugs fixed (https://bugzilla.redhat.com/):

    885569 - CVE-2012-5629 JBoss: allows empty password to authenticate against LDAP

    5. JIRA issues fixed (https://issues.jboss.org/):

    JBPAPP-10546 - CVE-2012-5629 - EAP5 Requires fix
    JBPAPP-10547 - CVE-2012-5629 - EAP4 Requires fix
    JBPAPP-10581 - CVE-2012-5629 One-off patch required for EAP/EWP-5.2.0
    JBPAPP-10582 - CVE-2012-5629 One-off patch required for EAP-4.3.0

    6. References:

    https://www.redhat.com/security/data/cve/CVE-2012-5629.html
    https://access.redhat.com/security/updates/classification/#important
    https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=appplatform&downloadType=securityPatches&version=5.2.0
    http://tools.ietf.org/html/rfc4513

    7. Contact:

    The Red Hat security contact is <secalert@redhat.com>.  More contact
    details at https://access.redhat.com/security/team/contact/

    Copyright 2013 Red Hat, Inc.

Issues are also displayed on the Customer Portal.

At the time of Errata Tool's 3.9 release, the customer portal had not yet been
updated to natively support the display of JIRA issues.  The issue links are
instead appended to the "References" section of the advisory:

[![jira_cp](images/jira/jira_cp.png)](images/jira/jira_cp.png)

The "References" section has a hard limit of 4000 characters.  JIRA issue links
are only displayed if this limit will not be exceeded.

Finally, issues are exposed via Errata Tool's HTTP/JSON API, as described in
[the relevant API documentation](https://errata.devel.redhat.com/developer-guide/api-http-api.html).

Private JIRA issues may only be seen within Errata Tool; all other systems
will only see the public issues associated with the advisory.

JIRA issue updates performed by Errata Tool
-------------------------------------------

Errata Tool will perform updates to JIRA issues in the following cases:

- When an issue is added to or removed from an advisory, a (private) comment is posted
  to the issue.

- When an advisory is shipped, a comment is posted on all associated
  issues.  The issues are also closed if permitted by the issue's workflow.

[![jira_comment](images/jira/jira_comment.png)](images/jira/jira_comment.png)

JIRA issue restrictions
-----------------------

Certain restrictions are placed on the usage of JIRA issues in Errata Tool.
Some of these are JIRA equivalents of existing rules for Bugzilla, and so
will be familiar to ET users.

**An issue may only be added to a single advisory.**
The Product Security Team may waive this restriction for RHSA.

**Issues with the "security" label are considered to be security-related issues.**
These may be added/removed from advisories even when the advisory is not
in the `NEW_FILES` state.  Additionally, only Product Security Team users may remove
these issues from advisories.  This is equivalent to using the "Security"
keyword on a Bugzilla bug.

**Issues with any non-public Security Level are considered to be private issues.**
These issues will not appear in any externally published errata metadata.
This is equivalent to setting a Bugzilla bug as private.

Errata Tool administrators can control which Security Levels are considered public
and private.  By default, for JBoss.org JIRA, only "Public" and "None" security levels
are considered public.  Any newly created Security Levels are considered private
by default.

Compared to Bugzilla bugs, several restrictions are notably omitted for JIRA issues.
In particular, the concept of an Approved Component List (ACL) and the CDW "3 acks" flags
are not used by Errata Tool when handling JIRA issues.
This may change in the future according to user feedback.

Errata Tool may be customized to apply different behavior for issues matching certain criteria.
Those customizations are not covered in this document.
