### Fixed TPS not rescheduling when adding builds

In Errata Tool 3.11.0, a change was made to the TPS scheduler to avoid
unnecessarily rescheduling jobs when adding/removing builds to a
subset of product versions in an advisory.  (See
[bug 1168893](https://bugzilla.redhat.com/show_bug.cgi?id=1168893).)

A flaw in this change meant that, in some cases, adding/removing
builds to an advisory would fail to trigger TPS rescheduling for
certain channels or repos.  This primarily affected errata for layered
products.

This has now been fixed (while retaining the TPS scheduling
improvement from 3.11.0).
