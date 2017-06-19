### Advisory ID now shown when for a bug which has the approved component already covered

Previously, when syncing or adding a bug for which the approved
component is already covered by another advisory, the Errata Tool
would state only that the bug was already covered.

With this change, the ID of the other advisory is now provided.  This
makes it easy to identify which advisory the bug should be added to,
and thus reduces unnecessary delays and support requests when creating
advisories.
