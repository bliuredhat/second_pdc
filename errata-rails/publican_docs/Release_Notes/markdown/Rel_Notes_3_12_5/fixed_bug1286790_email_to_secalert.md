### Send RHSA notifications to PST only after live push is complete

There is some manual processing for security advisories that is handled by the
Product Security Team. For this reason, when a non-security team member pushes
an advisory, the security team gets a notification email.

The notification was previously sent when the live push began. Because pushes
can take some time and sometimes don't complete successfully it's more efficient
for the PST's processes if the notification is sent only after the pushes have
completed successfully and the advisory has moved to SHIPPED\_LIVE.

Hence, in this release of Errata Tool, the notification email is triggered when
the advisory moves to SHIPPED\_LIVE rather than when it first moves to IN\_PUSH.
