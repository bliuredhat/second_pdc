Release Notes for Version 3.1
=============================

## Overview

Release 3.1 is the first minor release for Errata Tool 3 and was deloyed to
production on December 13th, 2012. It contains new functionality and bug fixes.

### Related Resources

* [PRD document for Errata Tool Release 3.1](https://dart.qe.lab.eng.bne.redhat.com/RAP/en-US/Errata_Tool/3.1/html/PRD/index.html)

* [Bug List for Errata Tool Release 3.1](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.1%2B)

## Advisory Dependencies

### Dependency UI Improvements

#### Adding "Depends on" and "Blocks" dependencies on the same page

Previously, when editing dependencies, you could add an advisory that the current
advisory "depends on". There was no way to add an advisory that the
current advisory "blocks" other than by going to that other advisory and
editing its dependencies.

Now you can add both type of dependencies from in the one place. This is
similar functionality to Bugzilla which provides both "Depends on" and
"Blocks" fields for creating bug dependencies.

Note that, as in Bugzilla, the relationships are symmetric, so if advisory A
depends on advisory B then advisory B blocks advisory A and vice versa.

The following screenshot shows the new "Edit Dependencies" page. Notice there
are two sections now, "depends on" and "blocks".

[![013](images/rel31/s013.png)](images/rel30/s013.png)

The form for adding and removing dependencies works similarly to how it worked
before. To add an advisory click the *+Add* button. The advisory can be
specified by either name or by id. Click *Ok* to add the advisory. To remove
an advisory click *Remove*.

#### Viewing Dependency Trees

If advisory A blocks advisory B, and advisory B blocks advisory C, then
effectively advisory A blocks advisory C indirectly. The dependency
relationships can be considered as a tree. In order to make the indirect
dependencies more visible, Errata Tool will now display the tree structure for
both the "depends on" advisories and the "blocks advisories".

This can be seen in the previous screenshot.

Note that the *Edit* link in the tree view section will take you directly to
the 'Edit Dependencies' page for that particular advisory. This should make it
easy to quickly setup or modify complex dependency trees if required.

It is also possible to view the dependency tree directly from the Information
section in the Summary tab (or the Details tab) by clicking the *View
Dependencies* button. This is shown in the following screenshot.

[![012](images/rel31/s012.png)](images/rel31/s012.png)

#### Restrictions On Adding Dependencies

Once an advisory reaches PUSH\_READY status its dependencies can no longer be
edited. If you need to change dependencies you need to move the advisory back
to REL\_PREP for example.

When adding advisory dependencies, the system will prevent you from creating
a dependency loop. For example if advisory A blocks advisory B, trying
to make advisory B block advisory A will be prevented and a message about creating
circular dependencies will be displayed. Dependency loops caused by indirect dependencies
are also detected and disallowed.

Dependencies that would cause a dependency rule to be broken will also be
prevented. For example if advisory A is set to block advisory B, but advisory
B is already shipped, then the system will not allow the dependency to be
created.

See also the next section on enforcing advisory dependencies.

### Enforcing Dependency Rules

In Errata Tool release 3.0 and earlier, advisory dependencies were
informational only and were not enforced by the system. In Errata Tool 3.1 the
dependencies are enforced. It will no longer be possible to ship an advisory if
it is blocked by some other advisory.

The enforcement of advisory dependencies happens when an advisory's state is
changed. There are two types of dependency rule enforcement.

#### When Moving to PUSH\_READY

The first type prevents advisories being shipped if they are blocked and
occurs when the advisory is moving from REL\_PREP to PUSH\_READY.

For example, if advisory A is blocked by advisory B, then advisory A can't
move to PUSH\_READY unless advisory B is already either PUSH\_READY or
SHIPPED\_LIVE. Advisory B must be moved to PUSH\_READY before advisory A can
be moved to PUSH\_READY.

#### When Moving Back to REL\_PREP

The second type prevents advisories that block other advisories from being
effectively "unshipped" and hence breaking a dependency rule.  This occurs
when an advisory moves from either PUSH\_READY or SHIPPED\_LIVE back to
REL\_PREP.

For example, if advisory A is blocked by advisory B and both are in
PUSH\_READY, then advisory B can't be moved back to REL\_PREP since it would
violate the dependency rule, ie that advisory B blocks advisory A. Advisory A
must be moved back to REL\_PREP before advisory B can be moved back to
REL\_PREP.

In the screenshot below an an advisory is being prevented from moving to
PUSH\_READY because of its dependency on another advisory that is not yet in
PUSH\_READY.

[![016](images/rel31/s016.png)](images/rel31/s016.png)

#### Workflow Rules

The dependency enforcement is implemented as a *state transition guard* and
hence can be enabled or disabled depending on the applicable workflow rule set. The
default workflow rule set will include the new state transition guards for advisory
dependency enforcement.

The next screenshot shows the dependency rules as they would appear when
viewing the default [workflow rule set](https://errata.devel.redhat.com/workflow_rules).

[![015](images/rel31/s015.png)](images/rel31/s015.png)

### Recording Dependency Changes

Previously, changes to dependencies were not recorded. Now there is a advisory comment
added whenever an advisory's dependencies are changed.

## Filing Advisories Improvements

### Bug Advisory Eligibility Page

In order to be eligible to be added to a Y-stream advisory a bug must meet a
number of requirements. Some of these requirements are quite complex and can
be difficult to explain to inexperienced users of Errata Tool, as well as
difficult to quickly analyse, even for experienced Errata Tool users and
administrators.

Developers creating an advisory, particularly using the "Create Y-stream
advisory using the ACL..." method, would often look for a particular bug or
package and be unable to find it due to one or more of the requirements being
unmet.  They would typically have no idea why they couldn't see their bug and
raise support tickets or ask for help.

Additionally, because Errata Tool syncs periodically with Bugzilla, there is a
delay between changes to a bug in Bugzilla and those changes being noticed by
Errata Tool. So in some cases the bug is only ineligible because it hasn't yet
synced. This problem is compounded because occasionally the Errata
Tool/Bugzilla sync process fails due to Bugzilla XML-RPC requests timing out.

The impact of the issues mentioned above is significant. Developers unable to
file their advisory would need to wait for help from Errata Tool support.
Errata Tool support staff would then need to look at the bug and spend
considerable time diagnosing what exactly is wrong and communicating how to
fix it. Because of timezone differences, this could often mean a minimum 24
delays in getting help with filing an advisory. Additionally when setting up new
products it often difficult to know which of the requirements for adding bugs
to advisories are met, and what still needs to be done to get things working.

So, to address these issues the new Bug Advisory Eligibility page (also known
as the 'Bug Troubleshooter' page) was created.  It's aim is to address the above
issues by:

- providing a quick analysis of a particular bug, showing information the bug
  relevant to its eligibility for inclusion in an advisory,
- presenting a checklist of advisory eligibility requirements for a bug,
  indicating which are met and which aren't met, and
- allowing a bug to be synced immediately with Bugzilla so that any issues
  related to the Bugzilla sync delay can be quickly eliminated.

This screen shot shows the page. You can see the bug information and the
eligibility check list. Below that it shows some other information about the
Approved Components List (ACL), as well as a list of advisories for the
applicable package and release.

[![017](images/rel31/s017.png)](images/rel31/s017.png)

The page is accessible from a number of places where the user is adding a bug
to an advisory, or creating a new advisory.

Because of the impact described above, this functionality was shipped early
in an Errata Tool hotfix release (Version 3.0-1) on November 7.

### Show Unavailable Packages & Bugs

In addition to the Bug Troubleshooter page described above, there is a change
to the 'Create Y-stream Advisory' page which also addresses the issue of
users creating an advisory not understanding why their bug or package is not
available.

The page where the package is selected will now show all bugs and packages
that might be eligible for an advisory, including the ones that are not
currently eligible for whatever reason.

Ineligible bugs and packages are shown crossed out to indicate they are
unavailable. For bugs there is a link to the Bug Troubleshooter page for that
particular bug, so a user can quickly find out why the bug is not available
when they are trying to create an advisory with that bug.

The following screen shot shows how that looks. The _"Why ineligible?"_ link
takes the user to the Bug Troubleshooter page for that particular bug.

[![018](images/rel31/s018.png)](images/rel31/s018.png)

Packages with no eligible bugs are also shown crossed out as in the following
screenshot.

[![019](images/rel31/s019.png)](images/rel31/s019.png)

As with the Bug Troubleshooter page, the aim for this functionality is to give
more information to the user creating an advisory, so they can quickly
diagnose why a particular bug or package they need to create an advisory for
is not available.

### TestOnly Bugs

Bugs that have the TestOnly keyword set can now be added to advisories when
they are in VERIFIED. Previously, they could only be added while ON\_QA.

### Creating Fast-Track Advisories

Previous the automated mechanism for creating advisories using ACLs and
approved bugs was only available for Y-stream advisories and Fast-track
advisories had to be created manually. In Errata Tool 3.1 the the automated
mechanism is available for Fast-Track advisories as well as Y-stream.

## CDN-only Product Support

Errata Tool now supports advisories that don't get pushed to RHN. (Previously
it was assumed that all advisories were pushed to RHN). CDN only products
will be able to peform all of the same post push tasks normally reserved
for push to RHN Live; closing bugs, pushing OVAL content, sending e-mails, etc.

### Configuring Product Versions

The push targets are configured at the Product Version level. Configuring
advisories for a particular Product Version to be pushed to CDN only is done
by editing the Product Version via the Errata Tool Admin Interface. The
different push types can now be enabled or disabled independently, as shown in
the following screen shot.

[![020](images/rel31/s020.png)](images/rel31/s020.png)

The changes related to this new functionality will make it easy to add
additional push types in the future.

The forbid\_ftp and supports\_cdn flags are now deprecated. They are inferred
from the set of push types. Users submitting data via json should include a
push\_types element enumerating the relevant types. For example:

```` JavaScript
 {
   "product_version": {
     "allow_rhn_debuginfo": true,
     "default_brew_tag": "dist-5E-qu-candidate",
     "is_rhel_addon": false,
     "base_product_version_id": null,
     "name": "RHEL-5",
     "push_types": [
        "rhn_live",
        "rhn_stage",
        "ftp"
     ],
     "product_id": 16,
     "description": "Red Hat Enterprise Linux 5",
   }
 }
````

## Documentation Approval Improvements

### Updating Docs Reviewer Improvements

Previously the only place where an advisory's docs reviewer could be changed
was the docs queue. It is now possible to update the docs reviewer from the
Summary tab, the Details tab or the Docs tab by clicking the `Change Docs
Reviewer` button.

The screenshot below shows the docs reviewer being updated from the Summary
tab.

[![023](images/rel31/s023.png)](images/rel31/s023.png)

### Docs Pages UI Improvements

Some improvements have been made to the advisory docs pages. They now share a
common header showing useful information related to the advisory's documentation
status. Button to edit the advisory content and change the docs reviewer are
available consistently on each documentation page.

It is now possible to request docs approval directly from the docs tab
instead of needing to go back to the summary tab to do it.

The screenshot below shows the area where the changes have been made.

[![021](images/rel31/s021.png)](images/rel31/s021.png)

### Rescinding Approval & Revision Number Bug Fix

A bug introduced in the previous release of Errata Tool was causing advisories
that had their documentation edited while in the PUSH\_READY state to not
properly have their documentation approval rescinded, and indirectly, not
properly increment the revision number. This bug is fixed in Errata Tool 3.1.

### Audit Synopsis Changes

Changes to an advisory's synopsis are now treated the same as changes to the
topic, problem description and solution. This means that synopsis changes will
now showing in the documentation diff history, generate a comment, and
potentially rescind documentation approval as per the other primary documentation
fields.

## ABI Diff Integration

ABI Diff is a new test performed on builds attached to advisories. The tests
will be automatically scheduled for builds by Errata Tool and, when available,
the results will be visible in the advisory's ABIDiff tab, in a similar way to
RPMDiff. These tests can be configured to run on a per product or per release
basis, gating any step of the release process.

This functionality is shipped in this release of Errata Tool, but will not be
enabled until the ABIDiff system goes into full production early in 2013.

## TPS Integration Fixes

The API call `/errata/ID/get_channel_packages` now returns all SRPMS in the
advisory, regardless of whether they are shipped to ftp. See
[bug 861247](https://bugzilla.redhat.com/show_bug.cgi?id=861247).

## Clearing CVE Names and Impact references

If a RHSA advisory is changed to an RHBA or and RHEA advisory, then fields
that are only appliable to RHSA are properly cleared. Additionally if the
impact level is changed, the impact link in the reference field will be
automatically updated.

## Other Bug Fixes & Improvements

Release 3.1 contains a number of miscellaneous improvements and bug-fixes.
The following is a list of bug fixes and RFEs not mentioned above.

### Enhancements

- [872503](https://bugzilla.redhat.com/show_bug.cgi?id=872503) [RFE] Make it clear that managers need to approve new accounts
- [860757](https://bugzilla.redhat.com/show_bug.cgi?id=860757) RFE: expose CVE list via JSON
- [866564](https://bugzilla.redhat.com/show_bug.cgi?id=866564) Only QA role users should be able to request signatures
- [867158](https://bugzilla.redhat.com/show_bug.cgi?id=867158) Give more useful error messages when release flag validation fails
- [868056](https://bugzilla.redhat.com/show_bug.cgi?id=868056) Add explanation text near advisory release drop-down about Z-stream vs Y-stream
- [871724](https://bugzilla.redhat.com/show_bug.cgi?id=871724) "RHEL5 Product Versions" text is confusing

### Bug Fixes

- [749691](https://bugzilla.redhat.com/show_bug.cgi?id=749691) "undefined method 'name\_nonvr' for nil:NilClass" at url /errata/show\_xml/2011-0212
- [873257](https://bugzilla.redhat.com/show_bug.cgi?id=873257) Typo: infomation on creating advisories
- [873993](https://bugzilla.redhat.com/show_bug.cgi?id=873993) Typos: Elegibility, Elegbility
- [876548](https://bugzilla.redhat.com/show_bug.cgi?id=876548) Editing channels throws 404
- [878434](https://bugzilla.redhat.com/show_bug.cgi?id=878434) undefined method 'new' for State:Module in ErrataService#get\_advisory\_list
- [879105](https://bugzilla.redhat.com/show_bug.cgi?id=879105) When creating a product need to add a default rule set (currently it is set to nil)
- [883179](https://bugzilla.redhat.com/show_bug.cgi?id=883179) Advisories assigned to users who are "default owners" are incorrectly displayed as unassigned
- [885528](https://bugzilla.redhat.com/show_bug.cgi?id=885528) inconsistent docs approval status between security/active and summary page

For further details, please see the full
[bug list](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.1%2B) in Bugzilla.
