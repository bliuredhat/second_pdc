### Info Request/Blocking Issue emails sent to default recipients

Errata Tool now sends emails to the following recipients whenever an
Info Request or Blocking Issue is opened for an advisory: the reporter,
package owner, QE assignee, and the advisory cc list. This is in
addition to any specific recipients that are configured for the requested
role.

Previously, not all Info Requests or Blocking Issues resulted in an email
being sent, depending on the requested role. This change helps to ensure
the appropriate people are made aware of these requests.
