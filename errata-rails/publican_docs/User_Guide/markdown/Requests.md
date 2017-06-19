Ticket Triage Procedures
========================

Account Creation Policy/Procedure
---------------------------------

Users who don't have access to Errata Tool, or who require additional roles, are
now instructed to request access through Maitai. Some requests may continue to
be filed through RT however, including requests to remove accounts and roles.

Requests may be created by sending an email to `errata-requests@redhat.com`.
This creates a ticket in the RT queue of the same name. Users are also informed
that their manager must approve the request before it can be actioned.

The procedure for processing these account request tickets is described below.

### Requiring Approval

- Before taking any action, wait for the manager to indicate their approval.
  Usually this is done by the manager responding on the ticket.

- If the ticket is sitting for a long period of time without any manager approval,
  or if it doesn't look like the requester has cc'ed their manager, then
  respond with a boilerplate reminder that manager approval is required.
    - If desired, the ticket can be moved to 'Stalled' at this point to indicate
      that it's waiting on a response and to remove it from the 'New' ticket queue.
    - Then, if the ticket sits stalled for a long period, it's okay to close the
      ticket with an explanatory message.

- Using the [Org Chart](https://people.engineering.redhat.com/), look up the
  requester's LDAP account details. Determine who their supervisor actually
  is. Ensure that the manager granting the approval is actually the
  requester's manager.

There are some variations to the manager approval requirement.

- If a manager is requesting an Errata Tool account to be created for a staff
  member they supervise, then there's no need to wait for approval since the
  existence of the request itself implies the manager's approval.

- If the requester is a senior manager or supervisor themselves then it's okay
  to create an Errata Tool account for them without waiting for approval from
  their manager or supervisor. (Though please use your own discretion here if
  the request seems unusual, especially if they are requesting the `admin` or
  `secalert` roles).

### Determining the Applicable Role

- From the [Org Chart](https://people.engineering.redhat.com/), determine what
  part of the company the requester works in. Where possible, based on their
  organization unit, classify them into one of the following categories.
    - Engineering
    - Quality Engineering (QE)
    - Release Configuration Management (Rel Eng)
    - Content Services (ECS)
    - Global Support (GSS)

- If they can be classified as one of the above categories, then use the
  following table to decide what Errata Tool role the user should have.

Organizational Unit Classification         Errata Tool Role
----------------------------------         ----------------
Engineering                                devel
Quality Engineering (QE)                   qa
Release Configuration Management (Rel Eng) releng
Content Services (ECS)                     docs
Global Support (GSS)                       readonly

- If the requester stated what role they want and it disagrees with the above
  table, (or if they asked for a particular role and don't clearly work in
  a corresponding organizational unit) then it's considered an unusual request.
  An explanation should be asked for if it's not already provided. For
  example: "You have requested the QA role but you don't work in QA. Can you
  explain why you need this role?" Unless the explanation is particularly
  convincing then move the ticket to the `errata-admin` queue where its
  validity can be reviewed by either Radek Biba or another Errata Tool
  administrator before granting the role.

- If the requester's organizational unit does not fall clearly into one of the
  above categories, and they did not state which role they require, then ask
  them which role they are requesting before deciding whether it can be granted.
  (Don't create an account until the requested role is known). If it's not
  clear whether the requested role agrees with the above table, then move the
  ticket to the errata-admin queue where it can be processed by an Errata Tool
  administrator.

- If the requester wants a role other than the roles listed in the above
  table, the ticket should generally be moved to the `errata-admin` queue
  where an Errata Tool administrator can decide what approval is required.

<note>

We may define some exceptions to this rule over time. For example a user can
be added to the Secalert role provided they have approval from Mark Cox.

Role Requested   Approval Required From
--------------   ----------------------
Secalert         Mark J Cox (mjc)
(tba)            (tba)

</note>

- In Errata Tool a user with no roles (other than the default `errata` role)
  has the same privileges as a user with the `readonly` role set. This means
  that they can't see embargoed advisories, can't comment on advisories, and
  won't be able to access some Errata Tool functionality.

### Resolving the Ticket

- Once the account is created and the role assigned, the ticket can be
  resolved with a response indicating the account has been created.
