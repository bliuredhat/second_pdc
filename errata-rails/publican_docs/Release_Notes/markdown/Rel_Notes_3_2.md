Release Notes for Version 3.2
=============================

Overview
--------

Release 3.2 is the second minor release for Errata Tool 3 and is currently
scheduled to be deployed to production in the first week of March, 2013. It
contains new functionality and bug fixes.

### Related Resources

* [PRD document for Errata Tool Release 3.2](https://dart.qe.lab.eng.bne.redhat.com/RAP/en-US/Errata_Tool/3.2/html/PRD/index.html)

* [Bug List for Errata Tool Release 3.2](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.2%2B)

Push Enhancements
-----------------

### Enable limited linking of optional channels to layered products (FR-1)

Layered products, in particular RHEV, have packages they depend on RHEL
optional channels being updated. At present they need to track these manually
and file separate advisories to push them to their channels. This is a manual,
time-consuming task and can potentially lead to required updates being missed.

If it were possible to ship packages to multiple products from a single
advisory it could eliminate the manual process of creating separate advisories
for effectively the same update. However, the concept that an advisory is for
a single product is well entrenched in Errata Tool and its related systems. A
lot of assumptions are made that depend on that design, hence to change that
would require significant re-architecting of Errata Tool and is not practical
in the short or medium term.

To alleviate the immediate problem, a solution was proposed for Errata Tool to
support defining set of packages that when pushed to an `-optional channel`,
will be in addition, automatically pushed to a related `-rhev` (or other)
channel. Errata Tool 3.2 supports this functionality.

Managing the set of packages and channels will initially be done manually,
though in future it may be exposed via the Administration UI.

See [Bug 849585](https://bugzilla.redhat.com/show_bug.cgi?id=849585) for more
details.

### Internal tool push support (FR-5)

There is an ongoing effort to 'dog food' Errata Tool with internal products
such as Beaker, Bugzilla and Errata Tool itself. The idea is that internal
products should use the same processes to manage releases as Red Hat products.
The CDW flag prefix support added in Errata Tool release 3.1 was part of this
effort.

In Errata 3.2 there is support for configurable push targets for
different products, so that internal products can push advisories to an
internal CDN/Pulp repo rather than RHN or (the public facing) CDN.

The admin UI for managing this configuration is shown below.

A product can be created and restricted to internal only push targets.

[![041](images/rel32/s041.png)](images/rel32/s041.png)

[![042](images/rel32/s042.png)](images/rel32/s042.png)

Any product versions created for that product inherit the restriction.

[![040](images/rel32/s040.png)](images/rel32/s040.png)

See [Bug 879119](https://bugzilla.redhat.com/show_bug.cgi?id=879119) for more
details.

### Support for 'reboot\_suggested' keyword (FR-6)

Advisories now have a new flag called `reboot_suggested`. This is used by
package manager clients (such as yum or PackageKit) to let the the user know
that a reboot should be done after installing the update.

Note that initially RHN does not support this flag, so it only takes affect
for advisories pushed via CDN.

The following screenshot shows the reboot\_suggested checkbox, available when
editing an advisory.

[![027](images/rel32/s027.png)](images/rel32/s027.png)

See [Bug 869677](https://bugzilla.redhat.com/show_bug.cgi?id=869677) for more
details.

Test System Integration
-----------------------

### Improve integration of manual TPS runs (FR-8)

When Errata Tool initiates a TPS run, it provides TPS with some important
information, such as the variant, the arch and the channel via the tps.txt
file.

For a manual TPS run (or a run initiated by Beaker), this information is not
always easy to discover or derive. Errata Tool 3.2 provides a mechanism for
TPS to request the information it needs to schedule a TPS run for a given
advisory.

The format is identical to the format provided in tps.txt so that it can be
parsed and handled by TPS in the same way.

See [Bug 889013](https://bugzilla.redhat.com/show_bug.cgi?id=889013) for more
details.

### Coverity Scan integration (FR-2)

Coverity is a commercial tool for doing analysis on software to detect
potential defects in C/C++ or Java code. Covscan is the Red Hat system that
can run Coverity Scans on brew builds and produce defect reports.

The Covscan team has been working with the Errata Tool team to provide a
mechanism for Errata Tool to automatically schedule a Coverity scan for builds
added to an advisory.

Errata Tool 3.2 will ship with support for automatically scheduling Coverity
scans. From Errata Tool's perspective the scans will work similarly to RPM
Diff or TPS tests. Initially however the Covscan integration will be launched
as a limited pilot. Scans will will only be initiated for a limited subset of
advisories, and the scan details won't be visible in Errata Tool for all users.

Scan results that require attention are marked as 'NEEDS\_INSPECTION'. The
developer can view the detailed scan report in Covscan and then either waive
the defect reports (or fix them in an updated build).

Depending on how the workflow rules are configured a scan that is not passed
or waived may block the advisory from moving to QE, or it may just be for
informational purposes only. (During the pilot period it will be informational
only and won't block the advisory).

More detailed documention on Covscan will be provided in a later documentation
update. The following screenshots show how the scans appear in Errata Tool and
in Covscan.

[![037](images/rel32/s037.png)](images/rel32/s037.png)

[![038](images/rel32/s038.png)](images/rel32/s038.png)

[![covscan](images/rel32/covscan.png)](images/rel32/covscan.png)

See [Bug 731716](https://bugzilla.redhat.com/show_bug.cgi?id=731716) for more
details.

Bugzilla Integration
--------------------

### Manually sync multiple bugs (FR-3)

The Bug Advisory Eligibilty page (also known as the 'bug troubleshooter page')
allows a bug to be synced with Bugzilla as required. Syncing a number of bugs
was only possible by viewing each bug individually and syncing them one at a time.

This release includes a new 'Sync Bug List' page where you can sync a number
of bugs by pasting their ids into a text box and clicking 'Sync Bugs'. This
makes it a lot easier and more convenient to sync many bugs, for example when
a Bugzilla outage has prevented the regular sync process from completing.

The 'Sync Bug List' page can be found by clicking 'Bugs' in the main toolbar,
and then clicking the 'Sync Bug List' tab.

[![024](images/rel32/s024.png)](images/rel32/s024.png)

Once the sync has completed the list of bugs that were synced is shown at the
bottom of the page with links to the troubleshooter page for each bug.

See [Bug 875961](https://bugzilla.redhat.com/show_bug.cgi?id=875961) for
more details.

[![025](images/rel32/s025.png)](images/rel32/s025.png)

### Notify Bugzilla of dropped bugs (FR-7)

In Errata Tool 3.2 when a bug is removed or a bug's advisory is dropped, a
comment will be added to the bug to indicate that it has been removed from
the advisory. Previously there was no way to tell that this had happened
when looking at the bug in Bugzilla.

See [Bug 839792](https://bugzilla.redhat.com/show_bug.cgi?id=839792) for
more details.

### Replace deprecated XML-RPC Calls

In an upcoming Bugzilla release, a number of XML-RPC methods will be removed.
These methods are for the most part replaced by similar upstream methods.
Errata Tool has been modified to use the new upstream methods so that when the
methods from the old API are removed Errata Tool will not be impacted.

For more details see bugs [822007](https://bugzilla.redhat.com/show_bug.cgi?id=822007)
and [881454](https://bugzilla.redhat.com/show_bug.cgi?id=881454).


Security
--------

### Embargo dates for RHEA and RHBA advisories (FR-4)

Previously only security advisories (RHSAs) could have an embargo date. In Errata
Tool 3.2 it is possible to set an embargo date on any type of advisory if required.

The screenshot below shows setting an embargo date for a RHBA advisory, and
the embargo date indicator showing in an advisory list for an RHBA advisory.

[![028](images/rel32/s028.png)](images/rel32/s028.png)

[![032](images/rel32/s032.png)](images/rel32/s032.png)

See [Bug 451790](https://bugzilla.redhat.com/show_bug.cgi?id=451790) for
more details.

Miscellaneous (FR-10)
---------------------

### Bug status count display

An advisory's Information section now gives an overview of bug counts by
status to provide a quick indication of progress of the advisory. Previously,
to get this information the user needed to look at the bug list and count up
the statuses manually, which is not very convenient, especially for an
advisory with many bugs.

Notice the 'Bug Statuses' field in the screenshot below:

[![033](images/rel32/s033.png)](images/rel32/s033.png)

See [Bug 820110](https://bugzilla.redhat.com/show_bug.cgi?id=820110) for
more details.

### Default to 'Show All Bugs'

Previously the default user preference was to show an abbreviated list of bugs
on the 'Summary' tab. In Errata Tool 3.2 this has been reversed so the default
is now to show all bugs in the 'Summary' tab. If you prefer the abbreviated
list you can set your preferences on the 'User Preferences' page (which can be
accessed by clicking your username near the top right of the page).

[![035](images/rel32/s035.png)](images/rel32/s035.png)

Additionally the threshold for showing an abbreviated bug list has been
increased to 12 bugs, so an advisory with less than 12 bugs won't ever show
the abbreviated bug list, and there is now a more noticible indication shown
when the bug list is abbreviated so that it is obvious when some bugs are not
visible.

[![034](images/rel32/s034.png)](images/rel32/s034.png)

See [Bug 872163](https://bugzilla.redhat.com/show_bug.cgi?id=872163) for
more details.

### Properly detect release in bug troubleshooter

The bug troubleshooter examines a bug's release flags to determine which
release it could belong to. In some cases it would not correctly find the
release. This is fixed in Errata Tool 3.2. Additionally, when a bug's release
flag matches multiple different releases, they will all be shown instead of
just one. The screenshot below shows this.

[![043](images/rel32/s043.png)](images/rel32/s043.png)

See [Bug 885525](https://bugzilla.redhat.com/show_bug.cgi?id=885525) for
more details.

### Include time stamps in push log

Errata Tool logs events related to pushes to RHN Live and RHN Stage and
displays the log on the Push Results page. Previously the log entries did not
include timestamps. In this release there are now timestamps in the push log
so you can see when each event related to the push job occurred.

[![pushlog](images/rel32/pushlog.png)](images/rel32/pushlog.png)

See [Bug 916341](https://bugzilla.redhat.com/show_bug.cgi?id=916341) for
more details.

### Other fixes and improvements

Please see the [bug list](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.2%2B)
for other miscellaneous bugs and RFEs not described here in the release notes.
