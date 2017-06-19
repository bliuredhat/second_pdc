### Allow updating an advisory's QE owner via the API

Systems which aim to automate the creation and management of advisories were
previously unable to set the advisory's QE owner easily via the API. This has
been addressed in Errata Tool 3.11.5.

The optional `assigned_to_email` parameter may be specified to set the
QA owner of an erratum. This parameter may be specified when creating a
new advisory, or to update an existing advisory.

An error will be returned if the value is not a valid Errata Tool user
with the QA role.

This change also includes making the `assigned_to_email` field editable along
with the other advisory fields when updating the advisory in the web UI.

A comment will be added to the advisory if this attribute is changed
(through either the API or UI).
