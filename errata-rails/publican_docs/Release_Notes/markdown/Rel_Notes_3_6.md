Release Notes for Version 3.6
=============================

Overview
--------

Release 3.6 is the sixth minor release for Errata Tool 3. It closes 62 RFEs
and bugs. During the 3.6 development period an additional 18 bugs were closed
in 3.5.x releases.

<emphasis role="new">new</emphasis>
:   Security users can now edit CPE texts after the advisory has been
    pushed.
    [Bug 1007327](https://bugzilla.redhat.com/show_bug.cgi?id=1007327)

<emphasis role="new">new</emphasis>
:   Bug components can be mapped to prefixed SCL package names.
    [Bug 1003719](https://bugzilla.redhat.com/show_bug.cgi?id=1003719)

<emphasis role="new">new</emphasis>
:   An easy way to view "related" advisories that have the same packages as
    the advisory you are looking at.
    [Bug 298121](https://bugzilla.redhat.com/show_bug.cgi?id=298121)

<emphasis role="improved">improved</emphasis>
:   The overall code quality improved for better maintenance and
    less recurring issues.

<emphasis role="improved">improved</emphasis>
:   Advisory assignees can clear the ``needinfo`` flag.
    [Bug 990670](https://bugzilla.redhat.com/show_bug.cgi?id=990670)

<emphasis role="improved">improved</emphasis>
:   Separate mail headers for notifications from comments and TPS runs
    [Bug 1019067](https://bugzilla.redhat.com/show_bug.cgi?id=1019067),
    [961376](https://bugzilla.redhat.com/show_bug.cgi?id=961376)

<emphasis role="improved">improved</emphasis>
:   Many [UI enhancements and fixes](https://bugzilla.redhat.com/buglist.cgi?classification=Internal&component=webui&f1=flagtypes.name&list_id=1878360&o1=substring&product=Errata%20Tool&query_format=advanced&v1=errata-3.6%2B).

<emphasis role="improved">improved</emphasis>
:   Improved internal bug eligibility checks to behave consistently when
    adding/removing bugs on advisories.
    [Bug 990318](https://bugzilla.redhat.com/show_bug.cgi?id=990318)
    [998852](https://bugzilla.redhat.com/show_bug.cgi?id=998852),
    [1000290](https://bugzilla.redhat.com/show_bug.cgi?id=1000290),
    [1012204](https://bugzilla.redhat.com/show_bug.cgi?id=1012204)

<emphasis role="fixed">fixed</emphasis>
:   Fix cloned advisories switching package maintainer/manager fields.
    [Bug 1007252](https://bugzilla.redhat.com/show_bug.cgi?id=1007252)

<emphasis role="fixed">fixed</emphasis>
:   Fix sometimes setting advisory roles to nil when given an invalid email address.
    [Bug 1007249](https://bugzilla.redhat.com/show_bug.cgi?id=1007249)

<emphasis role="developer">developer</emphasis>
:   [HTTP API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html)
    for creating and updating advisories.
    [Bug 989872](https://bugzilla.redhat.com/show_bug.cgi?id=989872)

<emphasis role="developer">developer</emphasis>
:   XMLRPC method ``get_advisory_list`` provides new fields.
    [Bug 986873](https://bugzilla.redhat.com/show_bug.cgi?id=986873)

For explanations and more details please read below.

### Related Resources

* [Release Announcement](https://docs.engineering.redhat.com/display/HTD/2013/11/15/Errata+Tool+3.6+Released)<!-- url tbc -->
* [Bug List for Errata Tool Release 3.6](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.6%2B)
* [Full code diff](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.6-0.0&id2=3.5-4.0)
* [Full code diff (from 3.5)](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.6-0.0&id2=3.5-0.0)


New Functionality
-----------------

### Post-push edits of CPE text for security users

Secalert sometimes needs to correct CPE metadata for an advisory after
it has been pushed to RHN. The CPE metadata is not part of the push.
We've added an additional form, which can be found under the
``Security`` menu for changing CPE text post-push. Only users with a
security role will have access to this form.

You can search for advisories in the form, by entering the advisory id.
Only shipped advisories can be looked up. After the advisory is found,
the form presents a text field with the current CPE value. Change it to
the new CPE value and click ``Save`` to apply the change to the
advisory.

[![fixcpe](images/rel36/fixcpe.png)](images/rel36/fixcpe.png)

For more details on this please see [bug
1007327](https://bugzilla.redhat.com/show_bug.cgi?id=1007327).

### Mapping bug components to prefixed package names

For an existing advisory, if you click the 'Add Bugs' button, Errata Tool will
provide a list of bugs that could be added to the advisory. The way that it
chooses these bugs is based on the advisories' packages and the bugs'
component.

Because RHSCL (and other layered products) have introduced a package name
prefix, this mechanism was not working and the only way to add a bug to an
existing advisory was to edit the advisory and type in the bug id.

For example, the package
[`python27-babel`](https://brewweb.devel.redhat.com/packageinfo?packageID=37282a)
has a package name of `python27-babel` but the bug component is still just
`babel`.  Since the package name and the component name are different, Errata
Tool was not able to match the bug component to the package name and hence it
would not correctly provide a list the bugs to be added to the advisory.

To deal with this problem Errata Tool has been made aware of brew rpm name
prefixes and can now correctly list bugs to be added to advisories with
prefixed package names.

(This functionality shipped in Errata Tool 3.5-3.0 on October 3rd).

Brew RPM name prefix lists are defined per product and are visible when
viewing the products in the admin UI. There is also a page that shows all the
currently defined prefixes. Currently it's not possible to derive the prefix
names from brew so the prefix lists are maintained manually.

[![rpm_prefixes](images/rel36/rpm_prefixes.png)](images/rel36/rpm_prefixes.png)

For more details see bugs
[959473](https://bugzilla.redhat.com/show_bug.cgi?id=959473),
[1003719](https://bugzilla.redhat.com/show_bug.cgi?id=1003719) and
[1027049](https://bugzilla.redhat.com/show_bug.cgi?id=1027049).


### New mechanism to see advisories sharing similar packages

Errata Tool provides a way to edit dependencies between advisories. But
what if you want to see advisories which share package information?

You can access the related advisories dialog from the summary page.
Click the ``More`` button, located next to ``Change State`` and choose
``Related Advisories`` from the drop down menu.

[![relatedmenu](images/rel36/related.png)](images/rel36/related.png)

Now you can see related advisories which share the same package. This
comes in handy if you like to see what bugs have been fixed in previous
advisories, what test cases were used, or simply what information is
shared.

Related advisories are sorted by package. In case of many advisories,
the dialog provides a quick access drop down menu on the right hand side
listing the different packages.

[![relatedadvisories](images/rel36/related_advisories_dialog.png)](images/rel36/related_advisories_dialog.png)

For more information please see [bug
298121](https://bugzilla.redhat.com/show_bug.cgi?id=298121).

### Managing 'Default Solution' text

The 'default solution text' is boilerplate text that gets added to an
advisory's solution field. It is now possible for admin users to modify this
text via the web UI. Previously there was no way to update this text other
than requesting a change by creating an RT ticket.

[![default_solution_edit](images/rel36/default_solution_edit.png)](images/rel36/default_solution_edit.png)

For additional details on this update please see [bug 631589](https://bugzilla.redhat.com/show_bug.cgi?id=631589).

Improvements
------------

### Advisory assignees can clear the ``needinfo`` flag.

In the past only, the requester or a user to which the request was
targeted was able to unset the flag. Now assignees can also clear the
flag, which makes it easier in cases where colleagues go on holidays or
are just unavailable.

For more info refer to [bug
990670](https://bugzilla.redhat.com/show_bug.cgi?id=990670).

### Separate mail headers for notifications from comments and TPS runs

We've tweaked the email headers for outgoing Errata tool mails in order
to help users with their email filtering.

* When TPS runs are rescheduled:

        X-ErrataTool-Action: TPS_RUNS_COMPLETE
        X-ErrataTool-Component: TPS

* When comments are added to an advisory, you can filter out ones for a
  particular user:

        X-ErrataTool-Who: errata-user@redhat.com

Further information is available at [bug 961376](https://bugzilla.redhat.com/show_bug.cgi?id=961376)
and [bug 1019067](https://bugzilla.redhat.com/show_bug.cgi?id=1019067).

### Improved and more consistent rules for adding bugs to advisories

We've cleaned up our code which now uses a single source to determine whether
a bug is eligibile to be added to an advisory. This is especially important
for bug eligibility tests when filing a new advisory through the Web UI as
well as via API calls.

Errata Tool will now behave consistently when it comes to determining a bug's
eligibility, and we now have a good starting point for documenting, refining
and adapting the business logic as required.

The refactoring work on the bug eligibility business logic was the background
work for a number of bugs, such as
[990318](https://bugzilla.redhat.com/show_bug.cgi?id=990318),
[998852](https://bugzilla.redhat.com/show_bug.cgi?id=998852),
[1000290](https://bugzilla.redhat.com/show_bug.cgi?id=1000290) and
[1012204](https://bugzilla.redhat.com/show_bug.cgi?id=1012204).

### Add 30 minute delay before scheduling TPS-RHNQA jobs after a push

In some cases TPS-RHNQA jobs were failing because the push to RHNQA hadn't
fully completed in time. In Errata Tool 3.6 there is a 30 minute delay is added
between doing the push and scheduling the TPS-RHQA jobs. This ensures that the
dependencies and packages are pushed fully before the TPS jobs are started.

For more details see [bug
1000232](https://bugzilla.redhat.com/show_bug.cgi?id=1000232).

### Better fault-tolerance creating CPE text cache files

Interruption of the cpe cache text file generation process could in some cases
result in the file being left empty. In Errata Tool 3.6 the creation process
is refactored to make this significantly less likely, and some sanity checking
is done to guard against truncated or corrupt CPE text being published.

For more information please see
[bug 1020567](https://bugzilla.redhat.com/show_bug.cgi?id=1020567) and
[bug 1021277](https://bugzilla.redhat.com/show_bug.cgi?id=1021277).

### Code quality improvements

With the introduction of a Continuous Integration System (Jenkins) in
our last release, we are now constantly gathering build statistics. With
this instrument in place, we've increased our code test coverage by **3.12%**
to 62.45%. This decreases the likelihood of recurring bugs and
increases the maintainability of the software.

[![Coverage Analysis for 3.6](images/rel36/rcov.png)](images/rel36/rcov.png)

We have consolidated code from several places in the application, making
it easier to test, re-use and fix inconsistent application behaviour.

[![Code Metrics for 3.6](images/rel36/codestats.png)](images/rel36/codestats.png)

For further information see [bug 990318](https://bugzilla.redhat.com/show_bug.cgi?id=990318)
and [bug 1007229](https://bugzilla.redhat.com/show_bug.cgi?id=1007229).


Fixes
-----

### Copied advisories no longer swap package maintainer/manager fields

For newly cloned advisories, we fixed a regression that was causing the
maintainer and manager fields to be incorrectly swapped around.

More information is available at [bug
1007252](https://bugzilla.redhat.com/show_bug.cgi?id=1007252).

(This fix was actually shipped in Errata Tool 3.5-4.0).

### The validation is fixed for the new advisory form

It was possible to file an advisory with blank/incorrect package
maintainer and manager fields. This was happening when an email address was
entered that was either badly formatted or didn't correspond to an Errata Tool
user. Instead of displaying a validation error the field was silently being
set to nil, which was then causing exceptions since in a lot of places the field
is expected to be present.

In Errata Tool 3.6 this bug is fixed and email addresses are validated
correctly.

[![validation](images/rel36/validation.png)](images/rel36/validation.png)

For further details please refer to [bug
1007249](https://bugzilla.redhat.com/show_bug.cgi?id=1007249).

(This fix was actually shipped in Errata Tool 3.5-4.0).

### Prevent moving to REL_PREP too soon

In some cases advisories were being moved to PUSH_READY ahead of their release
date. In Errata Tool 3.6 this is fixed and advisories will remained in
REL_PREP until their release date arrives.

For more info see [bug
1005162](https://bugzilla.redhat.com/show_bug.cgi?id=1005162).

### Malformed bug flags will not cause errors

There was an incident some time ago where the bug flags field synced from
Bugzilla was being truncated and hence causing Errata Tool to attempt to parse
malformed flags. Even though the field truncation issue has been resolved,
Errata Tool 3.6 will no longer throw an exception should it ever try to parse
a malformed or truncated bug flag. Instead if will just indicate that the flag
has an invalid status.

For more details see [bug
987205](https://bugzilla.redhat.com/show_bug.cgi?id=987205).

### Other fixes and enhancements

There were numerous other fixes and enhancements shipped in Errata Tool 3.6.
For a full list please see the
[Bug List for Errata Tool Release 3.6](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.6%2B)


Developer Related Improvements
------------------------------

### HTTP API

We've introduced an HTTP API to automate work with Errata Tool. The api
can be used to:

 * create, clone and update advisories,
 * add and remove bugs to advisories, and
 * change the state of an advisory.

The response of every API call is JSON encoded. The API methods are [documented
here](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html)

For more information please see [bug
989872](https://bugzilla.redhat.com/show_bug.cgi?id=989872).

### New Fields for XMLRPC call

We've improved the XMLRPC method ``get_advisory_list``, which can now be used to filter by:

* earlier or later than the issue date: ``issue_date_gt, issue_date_lte``,
* earlier or later than the update date: ``update_date_gt, update_date_lte``,

For more details see [bug
986873](https://bugzilla.redhat.com/show_bug.cgi?id=986873).


What's Next
-----------

### Errata Tool 3.7

The Errata Tool 3.7 will be different to most release cycles in that there
will be no new functionality added other then to upgrade to Rails 3.2.
(Currently Errata Tool runs on Rails 3.0).

There are a few dependencies that need to be packaged and some upgrade related
compatibility requirements, however since work began on this some time ago
much of the work is already done.

Because this affects the deployment environment we will need to coordinate
with eng-ops to ensure the production upgrade goes smoothly.

### Errata Tool 3.8

Planning for Errata Tool 3.8 will begin shortly after 3.6 is deployed. Bugs
and RFEs will be chosen from the backlog and from items that were originally
scheduled for previous releases but were pushed back. If you are interested
in being involved please subscribe to `errata-dev-list@redhat.com`.

<!--
(Put an X in column 1 if it's mentioned above)

# Bugs/RFEs in 3.6
 - 175617 [RFE] updatebugstates.cgi should use javascript show/hide toggle
X- 298121 [RFE]: Errata tool should list the links to previous rpm package related advisories in the right up corner of the "show/showrequest.cgi" page
X- 631589 Allow editing of Default Solution via webui
 - 856529 It's possible for two advisories to get the same live id
 - 961376 ET: incorrect "Tps Runs are now complete" mail headers
 - 980130 Allow non-SRT users to add CVEs/Security tracking bugs to RHSAs
 - 985239 Empty brew tags can be added for product version
 - 986873 [RFE] Add parameters to get_advisory_list xmlrpc call
 - 986894 Update default Solution text
X- 987205 BzFlag::Flag should not throw exceptions for malformed bz flags
 - 989469 Blank variant can be created for a product version
 - 989778 Don't show add me to cc list checkbox if user would already get email
X- 989872 [EPIC] JSON API: Expose create/update functions
X- 990318 [RFE] Adding bug via xmlrpc should use same bug eligibility rules as other methods
X- 990670 [RFE] allow user to clear needinfo flag
 - 991192 UI should state that an advisory cannot change state when marked as blocked.
 - 992905 Undefined method `each_pair' error in push/oval
 - 994558 FTP Push incorrectly shown as an option for advisory that does not support FTP
X- 998852 Automatically filed advisories may select TestOnly bugs in wrong state, cause exception on advisory creation
 - 999422 Incorrect sorting result on builds added since and covscan page
X- 1000232 Add a 30 minute delay before scheduling tps-rhnqa jobs after a push
X- 1000290 Bug Troubleshooter: In the case of TestOnly bugs, the MODIFIED state is not correct
 - 1002327 [Cleanup] application_helper bugzilla_host hits Setttings a huge number of times per page
 - 1002789 Dynamic confirmation messages should not fade out automatically
 - 1003766 Add rake task to publish schema information in json and sql format
 - 1004169 object_row_id helper is not working as expected and filling httpd error log with warnings
X- 1005162 Errata does not respect errata release date and switches the state to PUSH_READY
 - 1006193 get_rhn_filelists returns empty list in some cases
 - 1006644 [DOC]Spelling mistake in User Guide Chapter 3.1
 - 1006774 ET doesn't catch error in request_rhn_cache_update call
 - 1007229 The Open TPS Jobs page displays more than just open (scheduled) jobs
X- 1007327 [RFE] Add functionality to allow post-push edits of CPE
 - 1008380 product_version incorrectly sets forbid_ftp flag on new product versions
 - 1009215 [RFE] Allow rel-eng to manage products
 - 1010231 Disabled channels are indistinguishable on product version page
X- 1012204 The rules for adding bugs when creating an advisory using the Y-stream/ACL method are not suitable for RHSA creation
 - 1013425 Errata Tool has various obsolete links to Bugzilla
 - 1013531 "Request docs approval" check box does not work
 - 1014125 wrong file lists for rhel-7.0 redhat-release advisory
 - 1014430 Tell people on add bugs page that you can also add bugs by editing advisory
 - 1016540 Validation error messages contain escaped html links when adding invalid bugs
 - 1016994 [Regression] Secalert users should not be subjected to bug eligibility rules when adding bugs
 - 1017033 [Regression] CVE bugs with Security keyword can not be added to multiple RHSA any more
 - 1017091 [Regression] Fail to copy advisories as ACL is missing for many releases
 - 1017142 Can not clear all product versions for an existing async release
 - 1017489 [Regression]Fail to new a product with error "undefined method 'allow_ftp'" shown
 - 1017975 When filing a new erratum (Create manually), any mistake will forget preselected "Advisory Release" without any alternative
 - 1018022 Undefined method `user_organization_id' in reports/errata_by_engineering_group
 - 1019067 [RFE] add header X-ErrataTool-Who when comments add
X- 1020567 Don't open(.., 'w') file in Secalert::CpeMapper.publish_case until data is ready
X- 1021277 Create new CPE map text file as temp file and validate it before copying it over the existing one
 - 1021285 Make product_listing_caches unique on brew_build_id, product_version_id
 - 1024167 [Regression]undefined method `Error occurred setting errata cves` when trying to fix CVE names
 - 1024267 [Regression]Incorrect redirection after "Find Errata to Fix" on Fix CVE Names page
 - 1024444 Update OVAL schema from 5.3 to 5.10.1
 - 1024519 get_released_channel_packages should use channel link variant, not channel variant
 - 1024545 Add policy type ring to qpid connections
 - 1027049 Display SCL prefix mappings and give some instructions about requesting changes
# Hotfixes already shipped
 - 983717 channel list for text-only advisories needs to be expanded
 - 985262 Add comment button could not work for new created Y-stream advisory
 - 999459 [Regression] Can not create a foreign link RHN channel
 - 999949 rpmdiff bugzilla link - please update
 - 1001846 service name mismatch for qpid_daemon.rb
 - 1002348 Y-stream create throws an error about invalid security impact when creating an RHSA
 - 1002459 [Regression] Blank synopsis on preview page
X- 1003719 [EPIC] Implement method to map bug components to SCL package names (disregarding the derivation and maintenance of the mapping rules)
 - 1003760 Fix 'News' menu so it works with new Confluence release announcements RSS feed
 - 1003767 Add current_user to Piwik tracker custom field so it can collect user stats
 - 1004972 [Regression] Text only cpe edit field incorrectly hidden
 - 1005850 [Regression] Can't set Brew tags for RHEL-6-RHNTOOLS-6.4.Z
X- 1007249 [Regression] Can get nil package owner or manager during advisory create or update which causes exception when viewing advisory
 - 1007252 [Regression] Creating an erratum via copying swaps package maintainer/manager fields
 - 1007255 [Regression] Creating an erratum via copying does not copy over the dates
 - 1008259 Readonly (or no-roles user) can't see "Details" tab
 - 1012720 Creating an RHSA using Y-stream method sets synopsis incorrectly
-->
