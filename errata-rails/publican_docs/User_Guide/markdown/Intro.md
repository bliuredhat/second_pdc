Introduction
============

The Errata Tool is a system for managing the Red Hat Errata process. Errata
(singular 'erratum'), also known as *advisories*, are the vehicle by which
fixes and enhancements are released to customers for RHEL and other Red Hat
products.

***NB: This Users Guide is incomplete. Please see the 'Other
Resources' section for other sources of Errata Tool documentation***.

Errata Tool URLs
----------------
<!---
  Note: You need the four space indent for paragraphs that are inside the list
  item element but in a separate paragraph. Without the indent they will be
  outside the list.
-->

*   **Production** - <https://errata.devel.redhat.com/>

    The production system.

*   **Staging** - <https://errata-stage.app.eng.bos.redhat.com/>

    The staging server will generally run the same code release as production, but
    with non-production data. You can use the staging server to try things without
    affecting production advisories.

*   **Devel-staging** - <https://errata-devel.app.eng.bos.redhat.com/>

    The devel-staging server will normally run a pre-release version of Errata
    Tool. It is deployed to more frequently and hence may sometimes contain less stable code.

    (To be informed about what is currently deployed to devel-staging, subscribe to the
    [Errata Dev mailing list](http://post-office.corp.redhat.com/mailman/listinfo/errata-dev-list)).

Getting Access to Errata Tool
-----------------------------

### Authentication

To access Errata Tool you need to authenticate with your Kerberos credentials.
This should happen automatically if you have a current kerberos ticket and your
browser is [configured](http://people.redhat.com/mikeb/negotiate/) to support
negotiate authentication, otherwise you can enter your kerberos username and
password when prompted to authenticate.

(For more information on configuring kerberos authentication, see
[here](https://mojo.redhat.com/docs/DOC-87898)).

### Authorization

You may now request an Errata Tool user account, or additional roles for an
existing account, through [Maitai](https://maitai-bpms.engineering.redhat.com/).

To proceed, start the [Errata User Settings process](https://maitai-bpms.engineering.redhat.com/business-central/maitai/embeddingForm/startProcessForm?deploymentId=%27com.redhat.errata:errata-user-settings:1.4%27&url=%27https://maitai-bpms.engineering.redhat.com/business-central/%27&processId=%27errata-user-settings.Errata-User-Settings%27).

Default roles that matches your job title will be applied following manager approval.
Additional roles require justification, and further approvals, which may take longer.

If you already have an Errata Tool account, any requested new roles will be in
addition to those that are already assigned.

### Removal of Accounts or Roles

To request the removal of an Errata Tool account, or removal of roles from your
account, please file a ticket in Request Tracker (RT) by sending an email:

* addressed to `errata-requests@redhat.com`
* cc'ed to your functional manager
* mentioning the account name and kerberos login, preferably in the subject
* stating what changes are required

See the 'Roles' section below for details on the different Errata Tool user roles.

If you are unsure who your functional manager is, look yourself up in
[Rover People](https://rover.redhat.com/people/).

A typical subject line for the email might be:

~~~
Requesting removal of 'Qa' role in Errata Tool for Jane Fedora (user jfedora)
~~~

Account creation requests and role change requests require an approval ack
from your functional manager.

### Roles

A user's roles determine what they are allowed to do in Errata Tool. The roles
are as follows:

* **Readonly** -
  Readonly users can view errata but cannot modify or create them. They cannot view embargoed advisories.

* **Admin** -
  Can update admin pages for managing releases, products, channels, users, etc.
  (All non-readonly users can view the admin pages, but only admin users can update them.)

* **Covscan Admin** -
  Can reschedule Covscan runs and view Covscan related reports.

* **Createasync** -
  Can create ASYNC advisories.

* **Devel** -
  Can perform all Developer state transitions, and is able to file errata.

* **Docs** -
  Can approve, disapprove and edit errata documentation.
  Users in this role will show up as possible assignees in the Documentation Queue.

* **Management** -
  The management role is for Project, Quality Engineering and
  Development managers. These users will receive automated reports.

* **PM** -
  Project Management Group.

* **PushErrata** -
  Can push errata to RHN/CDN and perform related administrative actions.

* **QA** -
  Can perform all QA state transitions and will show up
  in the QA Owners list. Users in this role can be assigned to test errata.

* **RelEng** -
  Can perform all Release Engineers actions and are responsible for pushing
  content to RHN/CDN and the public FTP server.

* **SecAlert** -
  Users in the Product Security Team or otherwise privy to
  security sensitive errata information.

* **Signer** -
  Can sign packages with the Red Hat master keys. Signers receive e-mails
  for signature requests.

Reporting Problems
------------------

### Raising a Ticket in RT

If you have a problem or a request that probably doesn't require a code change to
fix (for example administrative tasks or a data related issue), raise a ticket
in Request Tracker in the 'errata-requests' queue. The easiest way to do this is to
send an email to `errata-requests@redhat.com`.

### Creating a Bug in Bugzilla

If you think you have found a bug or problem that requires a code modification
to fix, or you have a request for new functionality, you should create
a bug in Bugzilla.  The product name is 'Errata Tool'. You can find it under the 'Internal' classification,
or just use [this direct link](https://bugzilla.redhat.com/enter_bug.cgi?product=Errata%20Tool).
Choose the component that best fits.

For feature requests, create the bug in Bugzilla with the prefix \[RFE\] in
the bug's summary.

Errata Tool Team
----------------

Errata Tool is developed and maintained by **[PnT
DevOps](https://mojo.redhat.com/groups/pnt-devops)**.

For information on current team members and contact details please see
[People and Communication](https://docs.engineering.redhat.com/x/0IcEAQ).

Planning & Requirements
-----------------------

Requirements and planning for Errata Tool is discussed on the `errata-dev-list`
mailing list and managed in Bugzilla. For more information please enquire on the
mailing list.
