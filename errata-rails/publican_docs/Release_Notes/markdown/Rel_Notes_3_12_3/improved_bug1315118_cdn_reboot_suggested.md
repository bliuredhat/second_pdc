### Improve reboot_suggested handling for Pulp

When Errata Tool provides advisory metadata to Pub during a Pulp/CDN push, the
"reboot_suggested" flag on the advisory is now passed in two places: once on the
top-level advisory metadata object, and once on each package in the advisory package list.
Previously, this flag was only passed on the top-level object.

This change resolves an unintended difference between updateinfo XML published by
RHN Hosted and updateinfo XML published by Pulp.
