### Prevent automatic hard word wrapping of description text

A bug introduced in Errata Tool 3.9-3.0 (by the fix for [Bug
1032875](https://bugzilla.redhat.com/show_bug.cgi?id=1032875)) was causing
advisory descriptions to be automatically word wrapped to 80 characters and
saved with line breaks. These automatically added line breaks were causing
problems when the text is displayed with a different line length, and were
an inconvenience for subsequent editing of the description.

This has been fixed. The description field is now saved as is, without any
automatic word wrapping.
