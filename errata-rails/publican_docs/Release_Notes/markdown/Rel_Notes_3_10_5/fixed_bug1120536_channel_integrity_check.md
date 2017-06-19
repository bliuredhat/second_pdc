### Fixed missing validation on channel edit form

The form for creating or editing an RHN channel was missing a
validation on the channel type.  An attacker could exploit this to set
the channel type to an invalid value, effectively causing a Denial of
Service for that channel and for advisories using the channel.

This has been fixed by adding the missing server-side validation.
