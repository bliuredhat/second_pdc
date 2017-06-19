### Set "Reboot Suggested" automatically

The "Reboot Suggested" flag is now set automatically on advisories, based on the
packages shipped by the advisory.

[![Reboot Suggested](images/3.11.7/reboot_suggested.png)](images/3.11.7/reboot_suggested.png)

This flag determines whether a reboot of affected systems is recommended after
applying an advisory.  In previous versions of Errata Tool, the flag could be
manually set; however, the flag was rarely set, and could also be set
incorrectly.

To ensure that Reboot Suggested is set more accurately on advisories, this flag
is now automatically enabled if the advisory will ship any of a
[list of packages](https://access.redhat.com/solutions/27943) to Red Hat
Enterprise Linux 5, 6 or 7.  (To request a change to the list of packages,
please send an email to `errata-requests@redhat.com`.)

In order to maintain backwards-compatibility in Errata Tool's API, the
`reboot_suggested` flag is still accepted when modifying or creating an
advisory, but is ignored.  There is no change for API users reading the flag.

Additionally, this field is now correctly passed to pub for usage with RHN and
CDN.  Previously, Errata Tool always omitted the value or reported a value of
false to pub, even if the flag had explicitly been set to true.
