### Include "Reboot suggested" keyword in push to RHN

Since Errata Tool 3.11.7, the "reboot suggested" field on an advisory has been
passed as a flag to RHN during push.

As of this release, the "reboot_suggested" keyword will also be appended to the
keywords for an advisory where reboot is suggested.

This change allows the "Systems Requiring Reboot" feature in Red Hat Satellite 5
to correctly detect and show systems which should be rebooted after applying an
advisory.
