### Fixed advisories sometimes remaining in PUSH_READY after being edited

Editing an advisory with approved documentation causes its approval to be
rescinded. If the advisory is in PUSH_READY when this happens it should also
be moved back to REL_PREP where its documentation can be reviewed again.

A recently introduced bug was causing this automatic state change to not work
properly if the user also requested documentation approval at the same time
the PUSH\_READY advisory was updated. This caused some advisories to be
incorrectly in PUSH\_READY status without approved documentation. This has
been fixed in Errata Tool 3.11.2.
