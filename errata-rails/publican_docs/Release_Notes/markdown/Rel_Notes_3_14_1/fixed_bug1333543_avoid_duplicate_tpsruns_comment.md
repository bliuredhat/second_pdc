### Avoiding duplicate comments when tps runs complete

In some cases TPS would notify Errata Tool about completed TPS jobs multiple times.
This would create multiple duplicate "TPS runs are now complete" comments, and
multiple duplicate email notifications.

In this release Errata Tool will ignore the duplicate notifications from TPS and
create only a single comment and email notification.