### Prevent incorrect removal of 'Errata' role from users

A missing validation on the user administration page allowed the
Errata role to be removed from users, preventing them from reading and
commenting on errata.  This role is not supposed to be removable for
non-system accounts.

This has been fixed; the missing server-side validation has been
added.
