Static Analysis (Coverity) Scan Diffs
=====================================

About Covscan
-------------

Coverity Analysis is a static analysis tool that can detect a number of common
defects in C, C++ or Java source code. To some extent it also supports dynamic
languages (such as JavaScript, PHP, Python, or Ruby). It can scan source code
and produce reports on possible defects.

The instance of the Coverity scanning software deployed at Red Hat and the
system that schedules scans, displays results, and tracks waiving of defect
reports is known as _Covscan_. Besides Coverity Analysis, Covscan also runs
Clang Analyzer, Cppcheck, ShellCheck and other open-source static analyzers.

For more information about Covscan see the following resources:

- [Coverity Scan Project wiki][covscanwiki]
- [Covscan Workflow Documentation][covscandoc]
- [Covscan Announcement Email][covscanemail]

[covscanwiki]: https://engineering.redhat.com/trac/CoverityScan/wiki
[covscandoc]: http://cov01.lab.eng.brq.redhat.com/covscan_documentation.html
[covscanemail]: http://post-office.corp.redhat.com/archives/os-devel-list/2013-June/msg00002.html

Covscan & Errata Tool
---------------------

If an advisory's release (or product) is configured to use a Workflow Rule Set
that includes the 'Covcan' external test requirement then Errata Tool will
initiate a Covscan scan for any build added to the advisory.

The scan will be requested automatically as soon as the brew build is added to
the advisory's file list.

Covscan runs the scan twice, once against the latest stable build and once
against the new build. Then it reports on the differences between the two scan
reports. In this way it reveals potential issues that might have been
introduced in a new build.

Some more information about how the scans are performed is available in the
[workflow documentation][covscandoc] and the [announcement email][covscanemail]

To view scans for an advisory click the 'Covscan' tab while viewing an advisory.

[![002.png](images/covscan/002.png)](images/covscan/002.png)

Current & non-current scans
---------------------------

The scans are separated into two lists. The first list shows the 'current'
scans and the second list shows the 'non-current' scans.

When a scan is first created it is flagged as current. A scan becomes
non-current in the following ways:

- When its brew build is removed from the advisory, or obsoleted by a newer
  brew build being added.

- When it is rescheduled and hence replaced by a newer scan.

Scan statuses
-------------

The scan status is controlled by Covscan. When the status of a scan changes it
will inform Errata Tool (via the QPID Message Bus) of the status change and
Errata Tool will update the scan record's status.

The following scan status are considered by Errata Tool to be passing scans:

- `PASSED`
- `WAIVED`
- `INELIGIBLE`

Any other status is considered to be non-passing.

When all of an advisory's current scans are passing the advisory is considered to
be passing its Covscan external tests.

In the Approval Progress section of the Summary tab a summary of the passing
scans will be shown next to the 'External Tests' label.

[![003.png](images/covscan/003.png)](images/covscan/003.png)

Covscan decides if a particular build is eligible for a scan. Builds that do
not contain source code of any supported programming language are not eligible.
There are certain other builds that are classified as ineligible for other
reasons. Ineligible scans are considered passing as mentioned above.

<note>

The Covscan external tests can be configured to block the transition of an
advisory from `NEW_FILES` to `QE`, however the Workflow Rule Sets in current
use do not block this transition. This means that the non-passing Covscan
external tests are currently considered informational only and non-blocking.

In future this may be changed so that non-passing Covscan external tests will
block an advisory from transitioning to `QE` status.

</note>

Waiving a scan is done via the Covscan web interface. To access this click the
'View' link under the 'View in Covscan' column heading for a particular scan.

When a scan is waived, Covscan it will inform Errata Tool via the QPID
Message Bus that the scan's state has changed to `WAIVED`.

Please see the [Covscan Workflow Documentation][covscandoc] for information
about the correct way to waive a scan. You can also see information there
about other scan statuses and their meanings.

Getting Help
------------

If you need some assistance with Covscan, please create
a Trac ticket by emailing [covscan-auto][covscanauto] or using the [ticket
entry form][covscanticket].

[covscanauto]: mailto:covscan-auto@redhat.com
[covscanticket]: https://engineering.redhat.com/trac/CoverityScan/newticket
