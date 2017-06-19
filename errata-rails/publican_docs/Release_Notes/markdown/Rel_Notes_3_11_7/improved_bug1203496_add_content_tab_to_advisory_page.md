### Added content tab to advisory page

Previously, when working on an advisory, it was often hard to
decide whether the advisory should have multi-product support
enabled or disabled because Errata Tool didn't provide any
information about the effect of this feature.

This patch adds a content tab to the advisory page that provides useful
information about the additional channels or repos to which the advisory will
ship if multi-product support is enabled.  Therefore, it helps the user to
decide whether the feature should be enabled or not.

The new tab is also useful for any advisory since it can be used to
see and verify what content is going to be pushed where, and to
troubleshoot any problems.

[![Errata Content](images/3.11.7/errata_content.png)](images/3.11.7/errata_content.png)
