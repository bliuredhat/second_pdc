Release Notes for Version 3.9
=============================

Overview
--------

Release 3.9 is the ninth minor release for Errata Tool 3. It closes [86 bugs and
RFEs](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&f2=flagtypes.name&o1=substring&o2=notsubstring&product=Errata%20Tool&query_format=advanced&v1=errata-3.9%2B&v2=hot_fix).
The major new feature included in this release is support for integration
with JBoss JIRA. There are also significant changes to RPMDiff waiver
handling.

Additionally during the 3.9 development period an additional [26 bugs and
RFEs](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&f2=flagtypes.name&o1=substring&o2=substring&product=Errata%20Tool&query_format=advanced&v1=errata-3.9%2B&v2=hot_fix)
were shipped in 3.8.z releases, the majority being related to requirements for
testing and shipping RHEL 7.

### Highlights

<emphasis role="new">new</emphasis>
:   JBoss JIRA support.
    See [bug list](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&list_id=2524601&o1=substring&product=Errata%20Tool&query_format=advanced&short_desc=RFE%20JIRA&short_desc_type=allwordssubstr&v1=errata-3.9).

<emphasis role="new">new</emphasis>
:   Allow QE to approve/reject RPMDiff waivers.
    [Bug 494334](https://bugzilla.redhat.com/show_bug.cgi?id=494334).

<emphasis role="new">new</emphasis>
:   Synchronize user/group membership from OrgChart.
    [Bug 988608](https://bugzilla.redhat.com/show_bug.cgi?id=988608).

<emphasis role="new">new</emphasis>
:   Warn the user if no QE group can be automatically assigned.
    [Bug 1036148](https://bugzilla.redhat.com/show_bug.cgi?id=1036148).

<emphasis role="new">new</emphasis>
:   Added a bug activity log.
    [Bug 719614](https://bugzilla.redhat.com/show_bug.cgi?id=719614).

<emphasis role="improved">improved</emphasis>
:   Improved CDN support.
    See [bug list](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&list_id=2531910&o1=substring&product=Errata%20Tool&query_format=advanced&short_desc=CDN&short_desc_type=allwordssubstr&v1=errata-3.9).

<emphasis role="improved">improved</emphasis>
:   Allow bugs to be moved to ON_QA more than once.
    [Bug 719614](https://bugzilla.redhat.com/show_bug.cgi?id=719614).

<emphasis role="improved">improved</emphasis>
:   Accessibility and usability improvements for the push view.
    [Bug 1069980](https://bugzilla.redhat.com/show_bug.cgi?id=1069980).

<emphasis role="improved">improved</emphasis>
:   Reload file lists for all builds in errata.
    [Bug 868133](https://bugzilla.redhat.com/show_bug.cgi?id=868133).

<emphasis role="improved">improved</emphasis>
:   Make post-push tasks wait for combined RHN & CDN pushes to complete.
    [Bug 1071898](https://bugzilla.redhat.com/show_bug.cgi?id=1071898).

<emphasis role="improved">improved</emphasis>
:   Sync approved component list for all releases automatically.
    [Bug 1065827](https://bugzilla.redhat.com/show_bug.cgi?id=1065827).

<emphasis role="improved">improved</emphasis>
:   Allow creating CDN repo links in UI.
    [Bug 1091806](https://bugzilla.redhat.com/show_bug.cgi?id=1091806).

<emphasis role="improved">improved</emphasis>
:   Retry mail sending on temporary SMTP errors.
    [Bug 1108426](https://bugzilla.redhat.com/show_bug.cgi?id=1108426).

<emphasis role="improved">improved</emphasis>
:   Sync new Bugzilla bugs when adding via API.
    [Bug 1105719](https://bugzilla.redhat.com/show_bug.cgi?id=1105719).

<emphasis role="improved">improved</emphasis>
:   FTP SRPM links removed from errata emails.
    [Bug 1103959](https://bugzilla.redhat.com/show_bug.cgi?id=1103959).

<emphasis role="improved">improved</emphasis>
:   Allow filtering advisories using "Not in" option.
    [Bug 1010194](https://bugzilla.redhat.com/show_bug.cgi?id=1010194).

<emphasis role="fixed">fixed</emphasis>
:   Fix multi-product repositories missing from get_pulp_packages.
    [Bug 1091209](https://bugzilla.redhat.com/show_bug.cgi?id=1091209).

<emphasis role="fixed">fixed</emphasis>
:   Fix invalid TPS jobs remaining after removing builds from an advisory.
    [Bug 1074377](https://bugzilla.redhat.com/show_bug.cgi?id=1074377).

<emphasis role="fixed">fixed</emphasis>
:   Fix RHNQA/CDNQA TPS jobs scheduled too early when adding/removing builds.
    [Bug 1092194](https://bugzilla.redhat.com/show_bug.cgi?id=1092194).

<emphasis role="fixed">fixed</emphasis>
:   Fix linked CDN repositories missing from some views.
    [Bug 1097459](https://bugzilla.redhat.com/show_bug.cgi?id=1097459).

<emphasis role="fixed">fixed</emphasis>
:   Fix unlinked channels incorrectly displayed as linked in some views.
    [Bug 1097727](https://bugzilla.redhat.com/show_bug.cgi?id=1097727).

<emphasis role="fixed">fixed</emphasis>
:   Fixed RPMDiff runs incorrectly marked as obsolete on respin.
    [Bug 1077004](https://bugzilla.redhat.com/show_bug.cgi?id=1077004).

<emphasis role="fixed">fixed</emphasis>
:   Fixed TPS and RPMDiff using wrong released package on source package rename.
    [Bug 1074104](https://bugzilla.redhat.com/show_bug.cgi?id=1074104) and
    [bug 1103801](https://bugzilla.redhat.com/show_bug.cgi?id=1103801).

<emphasis role="fixed">fixed</emphasis>
:   Fixed spell check error highlighting.
    [Bug 494334](https://bugzilla.redhat.com/show_bug.cgi?id=494334).

### Related Resources

* [Release Announcement](https://docs.engineering.redhat.com/display/HTD/2014/07/11/Errata+Tool+3.9+Released)
* [Bug List for Errata Tool Release 3.9](https://bugzilla.redhat.com/buglist.cgi?product=Errata%20Tool&f1=flagtypes.name&o1=substring&v1=errata-3.9%2B)
* [Full code diff for this release](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.9-0.0&id2=3.8-5.0)
* [Full code diff (since 3.8)](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.9-0.0&id2=3.8-1.0)

JIRA Support
------------

JIRA is an issue tracking and project management system currently used
for JBoss products. This release adds support to file
advisories with JIRA issues referenced from the JBoss JIRA instance.

Advisories can now be associated with Bugzilla bugs and JIRA issues.
JIRA issues are added by entering the issue keys into the advisory
details. Bugzilla bug numbers and JIRA issue keys are accepted together.

[![jira_entry_form](images/rel39/jira_entry_form.png)](images/rel39/jira_entry_form.png)

The advisory summary page shows JIRA issues and Bugzilla bugs.
Further actions allow managing the associated issues.

[![jira_and_bugs](images/rel39/jira_and_bugs.png)](images/rel39/jira_and_bugs.png)

Errata Tool updates JIRA issues similarly to how it updates Bugzilla bugs,
including posting comments onto the issues, and closing the issues when an
advisory is shipped.

JIRA issues are included in the published errata data, including emails and the
Customer Portal.

We have also extended our APIs to accept JIRA issues. The HTTP API &ndash;
introduced in 3.6 &ndash; now provides methods to manage JIRA issues on advisories.

For more information on JBoss JIRA support, please see
[the User Guide](https://errata.devel.redhat.com/user-guide/jira-errata-jboss-jira.html).


RHEL 7 Requirements
-------------------

To support shipping RHEL 7 via CDN/Pulp (rather than RHN only) Errata Tool
needed a significant amount of new functionality. There was also a large
amount of testing by members of the Errata Tool QE team, and subsequent
related bug fixes and enhancements.

(The CDN/Pulp requirements for RHEL 7 were shipped in a series of 3.8-z
releases so they were available in time for RHEL 7 GA, however it's worth
mentioning them here since we don't have release notes for those updates).

Further details about CDN support and individual fixes and requirements can be
found below. The main high level new functionality is support for pushing
content to Pulp/CDN and for performing TPS on CDN subscribed systems.

To allow RHEL 7 to be shipped via CDN, Errata Tool needs to be aware of the
new push targets in Pub and know how to create the appropriate push jobs.
There were also a number of places where assumptions about advisories and RHN
needed to be revised and updated. Errata Tool needed to be able to deal
correctly with the workflow for advisories that push to CDN only, RHN only and
both CDN and RHN.

Additionally a large amount of testing was performed by the Errata Tool QE
team in conjunction with Release Engineering to ensure that the Errata Tool
&rarr; Pub &rarr; Pulp/CDN publishing process would work correctly for RHEL 7
advisories.

TPS tests that any RPMs shipped can be installed and removed cleanly on stable
systems. Previously this test was performed for packages distributed via RHN on
stable systems subscribed to RHN. It can now also test CDN distributed
packages on stable systems subscribed to CDN. Errata Tool maintains a list of
CDN repos so it knows which TPS jobs need to be scheduled for each advisory.

This required some database schema changes and testing in conjunction with QE
and the TPS development team.


Changes to RPMDiff Waivers
--------------------------

### QE can approve or reject RPMDiff waivers

QE users now have the ability to explicitly approve or reject RPMDiff waivers.

Reviewing RPMDiff waivers is a task commonly performed by QE, but earlier versions
of Errata Tool did not provide any mechanism to record the results of the review.
This new feature allows QE to perform this workflow more effectively.

[![rpmdiff_waivers_summary](images/rel39/rpmdiff_waivers_summary.png)](images/rel39/rpmdiff_waivers_summary.png)

Errata Tool's workflow rules can be customized to set RPMDiff waiver review as
optional, mandatory or disabled for each rule set.  In this release, waiver review
has been set as optional on each workflow rule set which uses RPMDiff.  Workflow
rule sets may be customized on request by contacting errata-requests@redhat.com.

[![rpmdiff_waivers_wf](images/rel39/rpmdiff_waivers_wf.png)](images/rel39/rpmdiff_waivers_wf.png)

This feature is supported by a new UI for reviewing RPMDiff results and waivers,
described below.

### New Manage Waivers UI for RPMDiff

A new user interface has been added for reviewing an advisory's RPMDiff results
and waivers. The new UI should make it easier and faster for developers and QE
to view and process waivers, particularly when there are a large number of them.

For developers, the new page shows RPMDiff failures, with the failure details
inline.  Multiple failures may be waived (with comments provided) as a single action.

[![rpmdiff_waivers](images/rel39/rpmdiff_waivers.png)](images/rel39/rpmdiff_waivers.png)

For QE, a similar view is presented.  RPMDiff waivers are displayed and may be
approved or rejected.

[![rpmdiff_waivers_qe](images/rel39/rpmdiff_waivers_qe.png)](images/rel39/rpmdiff_waivers_qe.png)


Other New Functionality
-----------------------

### Warn the user if no QE group can be automatically assigned

In cases where advisories are not automatically assigned a QE owner, there is
a risk of the advisory going unnoticed and its progress being delayed. This
can particularly become a problem for security advisories that sit in QE for a
long time because they don't have a QE owner.

[![warn_unassigned_qa](images/rel39/warn_unassigned_qa.png)](images/rel39/warn_unassigned_qa.png)

Errata Tool now shows an alert message if the advisory is not assigned
to a QE owner. The message is shown on the summary, as well as the
advisory details page. Part of the message is a link which opens the
dialog to assign a new QE owner.

For more details on this please see
[bug 1036148](https://bugzilla.redhat.com/show_bug.cgi?id=1036148)

### Synchronize user/group membership from OrgChart

User and group information is now periodically synchronized from
OrgChart.  This fixes outdated owners set on newly created advisories,
and similar issues, which have previously required manual intervention
to resolve.

The set of data synchronized from OrgChart includes:

* creating a new OrgChart group creates a corresponding new group in Errata Tool;
* modifying an OrgChart group parent, manager, or name updates the Errata
  Tool group accordingly; and
* adding or removing a user from a group in OrgChart performs the same
  update on the Errata Tool user.

Note that some user information (such as package ownership) doesn't
belong to OrgChart and is unaffected by this change.

For more information, please see
[bug 988608](https://bugzilla.redhat.com/show_bug.cgi?id=988608).

### Activity log added to bug troubleshooter

A new bug activity log has been added to the bottom of the bug
troubleshooting page.  Whenever Errata Tool modifies a Bugzilla bug, the
modification will appear in this log.  The log also records the reasons why
Errata Tool did _not_ modify a bug in cases where it is not appropriate to
do so, such as when the bug is in the wrong status, or when the bug is a
Security Response bug.

[![bug_activity_log_add_bug](images/rel39/bug_activity_log_add_bug.png)](images/rel39/bug_activity_log_add_bug.png)

The activity log gives users the ability to self-diagnose unexpected
behavior between Errata Tool and Bugzilla.  It also improves the audit
trail by retaining a permanent record of actions performed by Errata
Tool on Bugzilla.

[![bug_activity_log_removed_bug](images/rel39/bug_activity_log_removed_bug.png)](images/rel39/bug_activity_log_removed_bug.png)

For more information, please see
[bug 719614](https://bugzilla.redhat.com/show_bug.cgi?id=719614).

### Support new Bugzilla authentication mechanism

For security reasons, Bugzilla will soon disable its cookie-based
authentication mechanism. The new token-based authentication mechanism for
connecting to Bugzilla is now supported by Errata Tool so when the change
happens Errata Tool will not be adversely affected.

This update was shipped already in Errata Tool 3.8-3.1.

For more information, please see [bug
1089848](https://bugzilla.redhat.com/show_bug.cgi?id=1089848).


Improvements
------------

### Bugs may be moved to ON_QA more than once

Previous versions of Errata Tool would keep track of which bugs had
been moved from MODIFIED to ON_QA as a result of being added to an
advisory.  Errata would refuse to make this change a second time to
any bugs, even if the bugs were dropped from one advisory and added
to another.

A lengthy discussion in Bugzilla concluded that this restriction
has repeatedly caused confusion and has no clear rationale.
Therefore, in Errata Tool 3.9, this restriction has been removed.

For more information, please see
[bug 719614](https://bugzilla.redhat.com/show_bug.cgi?id=719614).

### File lists can be reloaded for all builds

File lists can now be reloaded for all builds in an advisory with a single request.
Previously it was necessary to reload file lists for each build individually,
a cumbersome process if many builds in an advisory needed to be reloaded.

This action may be performed via the builds page for an advisory or
via [the reload_builds API method](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html#method-i-reload_builds).

### Post-push tasks in combined RHN & CDN push

In earlier versions of Errata Tool, when performing an RHN and CDN push
together for an advisory, post-push tasks (such as closing Bugzilla bugs)
would always occur when the RHN push completed.  This would happen
regardless of whether the CDN push completed before or after the RHN push,
or even if fatal errors occurred during the CDN push.

This has been improved so that, for advisories applicable to both RHN
and CDN, most post-push tasks are only performed after both pushes
have succeeded.

For more information, please see
[bug 1071898](https://bugzilla.redhat.com/show_bug.cgi?id=1071898)

### Sync approved component list for all releases automatically

Approved Component Lists (or ACLs) previously have been synchronized
inconsistently from Bugzilla; the ACLs for some releases were regularly
synchronized while others were not.

It was determined that, in earlier versions of Errata Tool, a
semi-automated process had been used to set up the synchronization
of ACLs, and this process hadn't been applied consistently to all
releases.

This has been refactored and fully automated so that all ACLs are
synchronized into Errata Tool consistently.

For more information, please see
[bug 1065827](https://bugzilla.redhat.com/show_bug.cgi?id=1065827).

### Allow creating CDN repo links in UI

Previously, the RHN channel creation UI could be used to create
channel links between product versions, but this same feature was
missing from the CDN repository creation UI.

This functionality has been added, allowing CDN repository links
to be created in the same way as RHN channel links - by providing
the name of an existing repository.

For more information, please see
[bug 1091806](https://bugzilla.redhat.com/show_bug.cgi?id=1091806)

### Improved CDN support

We've spent time improving and testing CDN repository support in Errata
Tool in order ensure a successful launch of RHEL 7, the first product to
that Errata Tool has shipped via CDN.

We have improved in particular:

- Staging and Live pushes to different targets
- TPS tests are extended to test the distribution through Pulp
- Changes to variants to support CDN repositories and not only RHN
  channels

### Retry mail sending on temporary SMTP errors

Certain actions performed within Errata Tool cause email notifications
to be generated.  These include adding comments to an advisory, or
saving an advisory after editing various fields.

In previous versions, any kind of failure in delivering these
notifications could cause a fatal error in the user's request.  Worse,
the requested action in some cases may have been partially performed
and not rolled back when the error occurred.

This has been improved in Errata Tool 3.9 by adding a limited error
recovery mechanism to email delivery.

Further improvements are planned for future versions of Errata Tool
to decouple email delivery from all user actions.

For more information, please see
[bug 1108426](https://bugzilla.redhat.com/show_bug.cgi?id=1108426).

### Sync new Bugzilla bugs when adding via API

When adding bugs to an advisory via [the JSON API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html),
Errata Tool will now attempt to fetch any unrecognized bug numbers from Bugzilla.

This makes it easier to write scripts which programmatically create bugs and
add them to advisories.  Previously, such scripts would be subject to a race
condition, as the recently created Bugzilla bugs would not appear in Errata
Tool until the next Bugzilla to Errata Tool synchronization was performed.

For more information, please see
[bug 1105719](https://bugzilla.redhat.com/show_bug.cgi?id=1105719).

### FTP SRPM links removed from advisory shipped emails

With the launch of RHEL 7, source RPMs for advisories are now pushed
as git commits onto [git.centos.org](https://git.centos.org/project/rpms).

To support this change, advisory shipped emails no longer contain links to
SRPMs on ftp.redhat.com.

For more information, please see
[bug 1103959](https://bugzilla.redhat.com/show_bug.cgi?id=1103959).

### Accessibility and usability improvements for the push view

When dealing with advisories with multiple push targets, the push view
now provides improved accessibility and usability. Successful pushes are
collapsed, giving the focus to important push targets.

[![pushview](images/rel39/push_view.png)](images/rel39/push_view.png)

The submit button will be hidden if no pushes are selected. In cases of
unsuccessful pushes, these are selected by default if you continue to
the push view.

We also include a button that takes the user to the last successful push.

For more details see
[bug 1069980](https://bugzilla.redhat.com/show_bug.cgi?id=1069980).


### Allow filtering advisories using "Not in" option

You can now define advisory filter criteria as the negation of one of the
existing filter options. For example you could specify that you want a list of
all advisories that are not in a particular product or release. This is done
by checking the "Not in" checkbox on the applicable search option.

The negated search options can be combined with other search options as
required. The screen shot below shows a filter that would show RHEL advisories
that are not in the RHEL-7.0.0 release.

[![negated_filter](images/rel39/negated_filter.png)](images/rel39/negated_filter.png)

For further information please see
[bug 1010194](https://bugzilla.redhat.com/show_bug.cgi?id=1010194).

Fixes
-----

### Fix multi-product repositories missing from get_pulp_packages

For multi-product advisories using CDN, multi-product mapping
destination repositories would be incorrectly omitted from the values
returned by the get_pulp_packages endpoint.  This has been fixed.

This bug impacted TPS scheduling for multi-product advisories.
The fix was included in the Errata Tool hot-fix release 3.8-4.0.

For more information, please see
[bug 1091209](https://bugzilla.redhat.com/show_bug.cgi?id=1091209).

### Fix invalid TPS jobs remaining after removing builds from an advisory

When respinning an advisory to remove some builds after TPS jobs had
already been scheduled, Errata Tool didn't clean up jobs which were
no longer relevant.  This could result in wasted TPS resources and
confusing/misleading TPS results.

This has been fixed; removing builds now removes associated TPS jobs.

For more information, please see
[bug 1074377](https://bugzilla.redhat.com/show_bug.cgi?id=1074377).

### Fix RHNQA/CDNQA TPS jobs scheduled too early when adding/removing builds

When respinning an advisory to add or remove builds after TPS jobs
had already been scheduled, Errata Tool would incorrectly schedule
RHNQA and CDNQA TPS jobs before any RHN or CDN staging push had
occurred.

These jobs were hidden from the Errata Tool UI, but were included
in the TPS scheduling queue (tps.txt), resulting in wasted TPS
resources.

This has been fixed.

For more information, please see
[bug 1092194](https://bugzilla.redhat.com/show_bug.cgi?id=1092194).

### Fix linked channels and repos missing or displayed incorrectly

When RHN channels or CDN repositories were linked between product
versions, several views would show incorrect data:

* linked CDN repositories were incorrectly omitted from the index
  of CDN repos for a variant (both HTML and JSON views).
* unrelated RHN channels were incorrectly displayed as linked on
  the product version overview page.

The root cause of both of these problems was a faulty algorithm
for traversing linked channels and repos. This has been corrected.

For more information, please see
[bug 1097459](https://bugzilla.redhat.com/show_bug.cgi?id=1097459)
and
[bug 1097727](https://bugzilla.redhat.com/show_bug.cgi?id=1097727).

### RPMDiff results no longer incorrectly marked obsolete when updating builds

In previous versions of Errata Tool, whenever a brew build was removed from an advisory,
any RPMDiff results using that build were marked as obsolete.  This included updating
a package's build within an advisory.

Since Errata Tool version 2.2-11.2 was released in November 2011, when a build
for a package is updated in an advisory, RPMDiff will be scheduled comparing the earlier
and updated versions of the build.

These two behaviors combined meant that, for advisories with several respins, the total
set of non-obsolete RPMDiff results presented by Errata Tool would only cover the last
increment of the diff delivered by the advisory.

Since this flaw was introduced, it has caused several genuine regressions detected by
RPMDiff to be flagged as obsolete.

In Errata Tool 3.9, this has been fixed so that RPMDiff runs are not marked as obsolete
in this scenario.  This ensures the set of RPMDiff results presented by Errata Tool
more accurately cover the entire diff to be received by customers.

For more information, please see
[bug 1077004](https://bugzilla.redhat.com/show_bug.cgi?id=1077004).

### Fixed TPS and RPMDiff using wrong released package on source package rename

When determining the previously released version of a package for TPS or
RPMDiff scheduling, earlier versions of Errata Tool would only consider
the name of the source package.

This generated the wrong results in certain cases, such as:

* when a source package had been renamed;
* when a subpackage had been moved from one source package to another

This has been fixed; Errata Tool now correctly reports the latest released
packages to TPS and RPMDiff in these cases.

For more information, please see [bug 1074104](https://bugzilla.redhat.com/show_bug.cgi?id=1074104)
and [bug 1103801](https://bugzilla.redhat.com/show_bug.cgi?id=1103801).

### Fixed spell check error highlighting

Errata Tool does a spell check on advisory text and lists words that are not
found in its dictionary. It should also highlight the incorrectly spelled word
in on the preview page to make it easier to review the spell check results and
catch any typos.

Due to some incorrect CSS the highlight was not working. This has been fixed
in Errata Tool 3.9. The spelling errors are highlighted in yellow and are
underlined with a red dotted line as shown below.

[![spelling](images/rel39/spelling.png)](images/rel39/spelling.png)

Please see [bug 494840](https://bugzilla.redhat.com/show_bug.cgi?id=494840)
for more details.

Process Improvements & Team Changes
-----------------------------------

### Code coverage metrics

The current code coverage percentage of our test suite as reported by rcov on
Jenkins is 87.7%. This is significantly higher than previous releases, however
due to changes in the way we report coverage report this number can't be
compared to previous scores.

The change is that we are no longer excluding the tests themselves from the
coverage reporter in order to potentially identify dead code in the test
suite.

[![coverage](images/rel39/coverage.png)](images/rel39/coverage.png)

### New CI infrastructure

Our Jenkins server has been moved from a VM running on Roman's workstation,
([smitty](http://smitty.usersys.redhat.com/)), to an [OS1
internal](https://control.os1.phx2.redhat.com/dashboard/) Openstack instance
([novasmitty](http://novasmitty.usersys.redhat.com/)).

This is a big improvement since it means we have a more permanent home for
this increasingly crucial component of our infrastructure, and are less at
risk of interruptions if, for example the workstation VM goes down.

Some additional work was done to streamline the provisioning of Jenkins
slaves. This can now be done with a single Ansible playbook which creates and
configures and starts a Jenkins slave running under docker container.

For more information see [Errata Tool
Jenkins](https://docs.engineering.redhat.com/display/HTD/Errata+Tool+Jenkins).

### JIRA/Bugzilla syncing

Errata Tool bugs are now synced to (HSS) JIRA with flags and release
information intact. This will allow us to make use of JIRA's agile tools such
as task boards and burn-down charts to improve our Scrum practices.

(JIRA will be effectively read-only however, and we will continue to use
Bugzilla as the primary source for managing and tracking bugs and RFEs).

### Upcoming team changes

Effective August 1st Roman Joost (rjoost) and Hao Yu (hyu) will be leaving the
Errata Tool team and joining the RPMDiff team, and Kenichi Takemura (ktakemur)
from the STEP team will be joining the Errata Tool team.


What's Next
-----------

### Errata Tool 3.9.z

At this stage a 3.9-1.0 release is planned to switch on the new message bus
features. The message bus will be utilized by Bugzilla and JIRA in the near
future to improve the mechanism by which Errata Tool synchronizes bugs and
issues.

As usual there may be other 3.9-z releases scheduled as required for unexpected
or time critical fixes or updates.

### Errata Tool 3.10

The primary focus for Errata Tool 3.10 will be support for shipping non-RPM
based content. For more information on this and other upcoming features please
subscribe to the [mailing
list](http://post-office.corp.redhat.com/mailman/listinfo/errata-dev-list).

<!--
(Put an X in column 1 if it's mentioned above.
Put a dash if it's a regression and hence can be skipped.)

X 494334  [RFE] Explicitly require 'approve' 'deny' for each waiver
X 494840  ET: spelling errors no longer highlighted on the preview page
X 719614  MODIFIED bugs not moving to ON_QA
X 868133  [RFE] Reload filelists for all builds in errata
X 988608  [RFE] Errata Tool needs to sync with Orgchart to keep org unit/user relationships up to date
X 1010194  [RFE] Allow using negation in errata filter definition
  1014006  Docs Queue Load Speed is Very Slow (1 min.+?)
  1014007  ET: live_rhn_push.rb does not do push_xml_to_secalert and push_oval_to_secalert by default
X 1021799  [EPIC] Support JBoss.org JIRA as a bug source for errata
X 1036148  [RFE] Warn errata creator when no QE owner is found
X 1051936  [RFE]Update db/model to support JIRA issues
X 1051938  [RFE]Detect new/updated JIRA issues via JIRA public API
X 1051941  [RFE]Update Sync Bug List UI to support JIRA issues
X 1051942  [RFE]Update bug search UI to support JIRA issues
X 1051943  [RFE]Close JIRA issues when advisory is SHIPPED_LIVE
X 1051944  [RFE]Add JIRA private/security checks based on security level
X 1051945  [RFE]Accept JIRA issues in advisory create/edit UI
X 1051947  [RFE]Display JIRA issues in advisory view UI
X 1051948  [RFE]Update Errata output to display references to JIRA issues
X 1051950  [RFE]Post comments to an advisory when adding/dropping a JIRA issue
X 1052013  [RFE]Add JIRA support to JSON API
X 1053328  [RFE]Package jira-ruby gem for usage in Errata
X 1054037  [RFE]Post comments to a JIRA issue when added or dropped from an advisory
X 1054526  [RFE]Package qpid_proton gem for usage by Errata
- 1062497  JIRA issue keys containing a digit in the project part are rejected
- 1062500  idsfixed which are neither BZ ids or JIRA issue keys are silently ignored
X 1063147  Include JIRA issue data in RHN push
  1063533  New Advisory form shows incorrect Releases after refresh
X 1065827  Investigate why some releases do not get their component lists synced automatically
X 1066186  Add ET JIRA information to ET User Guide
  1066451  Can't sync the ACL for a non-default release in Bug Troubleshooter
X 1069007  Bug aliases in advisory edit form broken by JIRA support
X 1069980  Improve CDN&Live push option for the advisory with both CDN&RHN enabled
  1071849  Push to CDN item should be consistent with the status in advisory summary page when performing live push
X 1071898  [RFE] post-push tasks for CDN/RHN combined pushes
  1073162  Missing parameter in Noauth::ErrataController results in traceback
  1073696  Product listings page should preserve form state
X 1074104  get_released_channel_packages errors
X 1074377  The TPS jobs are not removed after related brew build removed
  1075989  The advisory is shown as SHIPPED LIVE without CDN pushed
  1076325  [RFE]ET should provide CDNQA(Pulp) TPS for advisories with both RHN&CDN enabled
X 1077004  rpmdiff runs are incorrectly considered obsolete whenever brew builds are updated
  1077523  The CDN TPS jobs of destination product version would be missing for the advisory with multiple destination supported
  1077987  Support for CDNQA (Pulp)
  1079228  CDN TPS jobs should be triggered correctly for base and optional repos
  1081816  [Regression]The approved packages are not shown in /errata/new_qu for FAST release for the related bugs have passed eligibility check
  1082096  RHN channels served where pulp repos expected
  1082441  [RFE] Support shipping a package to multiple products in 1 advisory via CDN
  1082849  Implement support for pulp stage (UI)
X 1082887  Make ET JIRA support able to be switched on or off
  1083168  xmlrpc `update_brew_build` call does not work
  1084231  TPS scheduler may set non-RHEL variants in some cases
  1085688  Refactor tps controller and some of the tps run methods
  1086045  get_pulp_packages omits SRPMS
- 1086144  Errata send incorrect md5sum to pub
  1088704  "CDN staging push"" should be added to advisory summary page"
  1088705  Item "Push to RHN Staging""  is shown as pass even if CDN staging push failed"
  1088706  Error "undefined method `distqa?'"" is shown  in DistQA TPS tab"
  1088734  Error creating Cdn stage push job as Validation failed "Push target can't be blank"""
  1088744  Migration to create cdn stage push target silently does nothing
  1088810  [Regression]No 30mins delay before scheduling tps-rhnqa jobs after RHN staging push
  1089205  CDN Staging Push is not available for Text Only advisory
  1089210  "Set Text Only CDN repos"" should be available for the Text Only advisories"
  1089774  Tps Queue does not include cdnqa jobs
X 1089848  Support new non-cookie based auth mechanism for bugzilla
  1090699  'Invalid push target name cdn_stage' error when running add_cdn_stage_push_target migration
  1090712  RHEL7 cdn push target should be cdn-live not cdn
X 1091209  The destination repos should be shown by calling get_pulp_packages
X 1091806  Should be able to create linked cdn repos (similar to linked channels)
X 1092194  Adding/removing builds can cause RHNQA or CDNQA TPS jobs to be scheduled too early
- 1093205  [Regression] TPS result waive is confirmed but status doesn't update
  1093524  Undefined 'name' for nil class exception when rescheduling rpm diffs
  1094073  In the errata model: is_assigned and unassigned can be the same
  1094147  Dependency check is ignored on CDN Staging push
- 1095968  Move and rename _content_display partial (Jira related)
X 1095991  Append JIRA issues to advisory references
- 1097043  Missing template error in jira issue and bug list page.
- 1097057  undefined method `descriptive_nil_class_link' error occurred for unsynced  jira issue from bug search page
- 1097119  ERROR: undefined method `key' when adding an invalid JIRA issue by JSON
- 1097121  jira issue can be added to advisory even it already existed in another advisory
  1097147  Clone a RHSA would create a RHBA incorrectly without secalert role
- 1097168  Security JIRA issue can be removed from RHSA by non-secalert user
- 1097172  ERROR: undefined method `id_jira' to show an invalid JIRA issue
X 1097459  Linked cdn repos are not being listed in a number of places
X 1097727  channel overview should display only related channels
- 1097950  JIRA issues are missing from the bug count on the main advisory table
  1098872  Need to refactor internal push logic since it depends too much on each push target.
  1099706  TPS fails for the mapped destination rhn channels/cdn repos as the released package information is missing
- 1100156  JIRA issues aren't removed when advisory is dropped
  1100209  CDN repos info are incorrect for the inherited variants which causes no CDN TPS jobs scheduled for Z-stream
  1100348  CDN repo types are missing
  1100524  Validate that rhel release for product version matches the rhel release of its variants
  1100790  unable to create new product
  1101061  Prevent exception being thrown when displaying a tps job with a deleted cdn repo or channel
  1101904  Unable to enable TPS for rhev cdn repos
  1102004  [Regression]Error "nil can't be coerced into Fixnum"" in docs list page"
  1102011  The variants are inconsistent with rhn and cdn tps jobs  for Z-release advisory
  1103074  TextOnly advisories are blocked by "Advisory must be up to date on RHN Stage"" incorrectly after successful RHN staging push"
X 1103801  Change in Brew name results in tps-make-lists failure
  1103957  The cdn repo json partial should include the new release_type field
X 1103959  [altsrc] Remove/replace FTP SRPM links from Errata emails for RHEL7
  1104000  Should prevent cdn repo being created with invalid release_type attribute
  1104407  Cannot delete a cdn repo when it has multiple links
  1104521  Errata Fixup - CPE doesn't work on non RHSA
- 1104975  The "finger"" test fails on Jenkins instances running on openstack because it makes assumptions about local user"
  1105361  Add autowaive related table to errata (required by RPMDiff 1.8.7).
X 1105719  RFE: sync bugzillas if not in errata.devel database
X 1108426  ET should retry sending mail on temporary SMTP errors
  1109040  undefined method `year' for nil:NilClass when accessing background_job
  1109108  undefined method `fetch' for nil:NilClass error on RHN staging push
  1109839  Help -> About leads to the general HSS landing page
- 1110563  Fix qpid_listener service connection problems (in 3.9 branch)
  1110972  Should provide a link to the approved component for a release list from release/show
  1111098  Push button should be hidden if no push task selected
- 1112058  Implement rpm version comparison in ruby and use that instead of rubygem-rpm (due to SSL problems)
  1112070  Internal Server Error when trying to fix CVE names
- 1112103  [Regression]No links shown for the added/removed bugs id in advisory comments
  1112141  The push tasks would set/update date even if doing live push with -nodate-update
  1112143  undefined method `<=>' for nil:NilClass error when viewing bugs in /bugs/troubleshoot page
  1112533  Refactor fetching brew builds to avoid strange bug on brew client timeout
  1112965  Push options and details are disappearred by default
  1112988  Details are empty in push errata page

-->
