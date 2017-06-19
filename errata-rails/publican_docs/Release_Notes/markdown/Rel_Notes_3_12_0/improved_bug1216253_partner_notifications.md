### Improved partner notification for embargoed advisories

Errata Tool generally notifies partners via
[the partner-testing mailing list](https://post-office.corp.redhat.com/mailman/listinfo/partner-testing)
when advisories become available for testing.

Previously, the handling of partner notifications was simplistic and failed to
send notifications in some cases; in particular, it did not allow notifications
to be sent after an advisory's embargo date had passed.

In this release, several improvements have been made to the notification
handling:

* Notifications can now be sent after an advisory's embargo date passes.

* Notifications can be sent if an advisory becomes eligible for notification
  after reaching the QE status.  Previously, if an advisory was not eligible for
  notification at the time it was moved to the QE status, it would never notify,
  even if it later became eligible.

* Notification eligibility now takes into account blocking bugs.  An advisory
  is now ineligible for notification if any of its bugs block a private
  Security Response bug, which is a new restriction.
