### Fixed filing bug by alias for bugs with multiple alias

When filing a Bugzilla bug on an advisory, Errata Tool generally allows
referring to the bug either by ID or by alias.  However, in previous versions of
Errata Tool, referring to a bug by alias did not work if the bug had multiple
aliases.

This was a regression introduced in Errata Tool 3.9.

This has been fixed. Bugs with multiple aliases may now be referred to using
their ID or any of their aliases.
