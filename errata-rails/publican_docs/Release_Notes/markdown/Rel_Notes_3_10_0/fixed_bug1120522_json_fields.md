### Add missing field to JSON response for CDN repos and channels

In Errata Tool 3.8 some changes were made related to TPS scheduling. In order
to make TPS scheduling more flexible and simpler to manage, rather than
maintain a list of stable systems within Errata Tool and use that to determine
how to schedule TPS jobs, Errata Tool now includes a boolean attribute on CDN
repo and channels to indicate that there are stable systems subscribed and
hence that TPS jobs can be scheduled.

The new attribute however was omitted from the JSON response data making it
difficult to find its value for scripts accessing Errata Tool repos and
channels. This has been fixed in Errata Tool 3.10 for both CDN repos and
channels.

Please see [Bug 1120522](https://bugzilla.redhat.com/show_bug.cgi?id=1120522)
for more information.
