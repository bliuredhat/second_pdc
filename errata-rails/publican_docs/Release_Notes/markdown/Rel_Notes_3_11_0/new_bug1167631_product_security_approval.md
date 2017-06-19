### Added Product Security Approval workflow step for RHSA

A new approval step has been introduced for security advisories.  From
Errata Tool 3.11 onwards, it's now necessary for RHSA to be approved
by a member of the Product Security Team before the advisory may move
to PUSH_READY.

This approval step appears in the UI similarly to the existing Docs
Approval step, as in the below example:

![Product Security Approval step](images/3.11.0/product_security_approval.png)

A new system filter has been added for the Product Security Team to
find all errata awaiting security approval.  User filters may also
make use of the Security Approval status.

![Product Security Approval filter](images/3.11.0/security_approval_filter.png)

This workflow change is an enabler for future process improvements
regarding security advisories.  The intent is to allow more security
advisories to be created/updated by users outside of the Product
Security Team, but still require a member of that team to review the
advisory before shipping.
