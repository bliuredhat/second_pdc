### Fixed QE assignee copied when cloning advisory

This change fixes a regression introduced by
[bug 1234750](https://bugzilla.redhat.com/show_bug.cgi?id=1234750),
whereby the QE assignee was copied from the template erratum when cloned.

The QE assignee on new cloned advisories should be left as the default.
