### Add an optional email address field to User

An email_address field has been added to the user account.

Previously, the login_name from Kerberos principal was used to receive any
notification from Errata Tool.

Errata Tool no longer defaults to the Kerberos login name to send notifications
to. Users can now add a separate email address for receiving notifications.

This feature is especially useful for service accounts which use a keytab to
authenticate.
