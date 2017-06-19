Release Notes for Version 3.8
=============================

Overview
--------

Release 3.8 is the eighth minor release for Errata Tool 3. It closes 9 RFEs
and 62 bugs. During the 3.8 development period an additional 4 bugs were closed
in 3.7.x releases.

<emphasis role="new">new</emphasis>
:   Support for shipping a package to multiple products.
    [Bug 996238](https://bugzilla.redhat.com/show_bug.cgi?id=996238)

<emphasis role="new">new</emphasis>
:   New page to view multi-product channel mappings.
    [Bug 1033382](https://bugzilla.redhat.com/show_bug.cgi?id=1033382)

<emphasis role="new">new</emphasis>
:   RHNQA jobs are scheduled with a 30 minute delay.
    [Bug 1069977](https://bugzilla.redhat.com/show_bug.cgi?id=1069977)

<emphasis role="new">new</emphasis>
:   JBEAP Rebase Bugs now move to ON_QA only when advisory is changed to QE.
    [Bug 1007511](https://bugzilla.redhat.com/show_bug.cgi?id=1007511)

<emphasis role="improved">improved</emphasis>
:   Improved support for CDN [see Bugzilla](https://bugzilla.redhat.com/buglist.cgi?quicksearch=product%3A%22Errata%20Tool%22%20flag%3A3.8%2B%20summary%3ACDN&list_id=2275161)

<emphasis role="improved">improved</emphasis>
:   Docs Queue loads 35% faster.
    [Bug 965922](https://bugzilla.redhat.com/show_bug.cgi?id=965922)

<emphasis role="improved">improved</emphasis>
:   New Y-Stream advisory bug list loads 50% faster for RHEL-7.0.
    [Bug 1017918](https://bugzilla.redhat.com/show_bug.cgi?id=1017918)

<emphasis role="improved">improved</emphasis>
:   Improved application stability when importing a large number of
    release builds.
    [Bug 1012710](https://bugzilla.redhat.com/show_bug.cgi?id=1012710)

<emphasis role="improved">improved</emphasis>
:   Add bugs page shows more bugs to select.
    [Bug 1067483](https://bugzilla.redhat.com/show_bug.cgi?id=1067483)

<emphasis role="fixed">fixed</emphasis>
:   Ensure only one advisory can be created for an X.Y update.
    [Bug 236947](https://bugzilla.redhat.com/show_bug.cgi?id=236947)

<emphasis role="fixed">fixed</emphasis>
:   Removal of brew builds now marks associated rpmdiff runs as
    obsolete.
    [Bug 485395](https://bugzilla.redhat.com/show_bug.cgi?id=485395)

<emphasis role="fixed">fixed</emphasis>
:   Read-only users can now save search filters.
    [Bug 1066247](https://bugzilla.redhat.com/show_bug.cgi?id=1066247)

<emphasis role="fixed">fixed</emphasis>
:   New QuarterlyUpdate form keeps values on validation error.
    [Bug 1025602](https://bugzilla.redhat.com/show_bug.cgi?id=1025602)

<emphasis role="fixed">fixed</emphasis>
:   Bugs can be added to FAST releases without ACL checking.
    [Bug 1066786](https://bugzilla.redhat.com/show_bug.cgi?id=1066786)

<emphasis role="fixed">fixed</emphasis>
:   Remove impact prefix from synopsis when converting from RHSA to RHBA.
    [Bug 920907](https://bugzilla.redhat.com/show_bug.cgi?id=920907)

<emphasis role="developer">developer</emphasis>
:   [HTTP API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html)
    for adding and removing brew builds.
    [Bug 1028222](https://bugzilla.redhat.com/show_bug.cgi?id=1028222)

<emphasis role="developer">developer</emphasis>
:   Additional options for `live_rhn_push.rb` command line tool.
    [Bug 1060586](https://bugzilla.redhat.com/show_bug.cgi?id=1060586)

For explanations and more details please read below.

### Related Resources

* [Release Announcement](https://docs.engineering.redhat.com/display/HTD/2014/04/01/Errata+Tool+3.8+Released)
* [Bug List for Errata Tool Release 3.8](https://bugzilla.redhat.com/buglist.cgi?product=Errata%20Tool&f1=flagtypes.name&o1=substring&v1=errata-3.8%2B)
* [Full code diff](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.8-0.0&id2=3.7-4.0)
* [Full code diff (from 3.7)](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.8-0.0&id2=3.7-0.0)


New Functionality
-----------------

### Shipping a package to multiple products

Errata Tool can now be used to create advisories that ship packages to
multiple products. This is configured per package for each product version.
If configured to do so, the package will be shipped to the 'destination'
channel in addition to the 'origin' channel.

This extends the initial Layered/Optional channel mappings support shipped
in Errata Tool 3.6 and makes it more flexible and configurable.

In order to ship to multiple products an advisory must have the 'Support
Multiple Products?' flag checked. This flag is settable by `releng`, `admin`
and `secalert` users only.

Multi-product advisories are distinguishable in advisory lists, the summary
tab and the details tab using a text indicator similar to the 'text only'
indicator.

### Multiple product channel mappings now visible

In Errata Tool 3.7 the Layered/Optional channel mappings were not easily
viewable via the UI. In Errata 3.8 there is a page showing the current
mappings accessible by clicking the 'Multiple Product Channel Mappings' link
on the Admin index page.

Note that it's currently not possible to modify the mappings via the web UI.
Additional mappings can be requested by emailing `errata-requests@redhat.com`
to create a ticket in RT.

[![multiproductmap](images/rel38/multiproductmap.png)](images/rel38/multiproductmap.png)

### RHNQA jobs are scheduled with a 30 minute delay

After Errata performs a push to RHN stage, the TPS system usually tries
to start testing packages immediately. This would cause some tests to fail,
as the publishing of packages was not always completed by the time TPS
attempted to test them. Users were forced to manually re-schedule the
failing tests.

To work around this problem, we've introduced a delay before RHNQA tests
are scheduled. The UI provides a simple feedback on the summary page in
order to see when the tests are being queued for TPS.

[![rhnqa30min](images/rel38/rhnqa30min_indicator.png)](images/rel38/rhnqa30min_indicator.png)


Improvements
------------

### Improved support for CDN

CDN (via Pulp) is becoming an important repository for package distribution
next to RHN, and will be the main distribution mechanisn for RHEL-7.

Errata Tool has had basic support for pushing packages to CDN for some time,
but until this release it has not been tested thoroughly, nor used in
production.

With this release, we've improved the overall support for CDN. This
ranges from dealing with advisories which push packages only to CDN,
to changing the logic internal release tests.

There were a few places where Errata Tool made some assumptions about
advisories and RHN that are no longer always true. These have been cleaned up.

[![cdnonly](images/rel38/cdnonly.png)](images/rel38/cdnonly.png)

The improved support includes:

  * Advisory summary provides a link to the CDN push page
  * Bugs in Bugzilla are automatically closed (as with RHN pushes)
  * TPS testing is supported for CDN-only advisories
  * Improved form validation when creating CDN repositories
  * Better handling of pre- and post-push tasks

[See Bugzilla](https://bugzilla.redhat.com/buglist.cgi?quicksearch=product%3A%22Errata%20Tool%22%20flag%3A3.8%2B%20summary%3ACDN&list_id=2275161) for more information.

### TPS scheduling improvements

In Errata Tool 3.8 the TPS scheduling mechanisms have been refactored.
Previously Errata Tool maintained a list of available stable systems
and used that list to decide how to schedule TPS jobs. Errata Tool 3.8
uses a new channel-based mechanism which is easier to maintain and allows
greater flexibility.

The refactor also provided the framework for adding support for CDN
repo-based scheduling of CDN/Pulp TPS jobs, which are required for RHEL-7.

Some more details are available at [bug
1012774](https://bugzilla.redhat.com/show_bug.cgi?id=1012774).

### Support for sha256 checksums

Pulp uses sha256 checksums for rpms instead of md5. Support for the new
checksum type has been added to Errata Tool 3.8

Please see [bug
1004895](https://bugzilla.redhat.com/show_bug.cgi?id=1004895) for more
details.

### Docs Queue loads 35% faster

The Docs Queue provides information and functionality for documentation
writers. Previously, the way the page was generated and rendered caused
major overheads for Errata Tool and the browser.

We have implemented changes to dynamically load page elements, reducing
the number of elements the browser has to render and Errata Tool has to
generate.

These changes decrease the page load time of the docs queue by 35%, resulting
in a better user experience.

For more information, please see [bug 965922](https://bugzilla.redhat.com/show_bug.cgi?id=965922).

### New Y-Stream Advisory bug list loads 50% faster for RHEL-7.0

When creating a new Y-Stream advisory, Errata presents a list of eligible
and ineligible packages and bugs for the advisory, using the Approved
Component List.

For RHEL 7, the approved component list contains every component.  As a result,
the package/bug list contained a very large number of items, causing the page to
load slowly.

We have implemented changes to Errata to improve rendering performance for this
page, and changes to the bug list to only show eligible bugs by default if the
total number of bugs is large.  A link is provided to load the ineligible bugs.

These changes decrease the load time of the package list by up to 50% resulting
in a better user experience.

For more information, please see [bug 1017918](https://bugzilla.redhat.com/show_bug.cgi?id=1017918).

### Improved application stability when importing large number of release builds

For release engineers importing a large number of release builds, we've
improved the stability of the application.

Previously, Errata Tool would attempt to import all provided builds in a single
request before returning a result to the user.  This would frequently cause timeouts
when a large number of builds was provided.

In Errata Tool 3.8, this import process has been moved to a background job, improving
the reliability of the import.  The user performing the import receives an email
when the import jobs complete.

The mechanism for tracking a set of background jobs and informing the user
when they are complete is generic and can be reused for other long running
tasks.

For more information, please see [bug 1017918](https://bugzilla.redhat.com/show_bug.cgi?id=1012710).

### Add bugs page shows more bugs to select

The "Add Bugs" view allows users to select new bugs relating to the
advisory. We have improved the list so it shows more bugs due to
consistently applied eligibility rules.

[![addbugs](images/rel38/addbugs.png)](images/rel38/addbugs.png)

### ACL lists sync can now be performed by non-admin users

Because bugs can't be added to an advisory unless their component is on the
approved component list (ACL) for the applicable release, an out-of-sync ACL
can prevent a bug being added and hence delay an advisory's progress.

The Bug Advisory Eligibility page provides a button that performs an immediate
sync of a release's approved component list from Bugzilla. Previously this
button was only available to admin users. In Errata Tool 3.8 this is now
available to any Errata Tool user so that affected advisories can be
more quickly progressed.

[![syncacl](images/rel38/syncacl.png)](images/rel38/syncacl.png)

For more details, please see
[bug 1065809](https://bugzilla.redhat.com/show_bug.cgi?id=1065809).

### Show reboot_suggested flag for advisory

The 'reboot suggested' advisory flag was added some time ago but was only
visible when editing an advisory. In Errata Tool 3.8 the flag is now visible
when viewing an advisory's details.

For more information, please see
[bug 1030548](https://bugzilla.redhat.com/show_bug.cgi?id=1030548).

### Code Coverage Metrics

Since the Errata Tool 3.6 release our code coverage ratio has increased by
**7.18%** from 62.45% to 69.63%. Increased code coverage means better
maintainability, and a reduced chance of shipping regressions and new bugs.
It also means we can more confidently refactor and improve existing code.

[![rcov](images/rel38/rcov.png)](images/rel38/rcov.png)

Fixes
-----

### Read-only users can now save search filters.

For users browsing advisories in Errata Tool, we've fixed a bug
that prevented viewing and saving of advisory search filters.

[![readonlysavesfilters](images/rel38/readonly_save_filters.png)](images/rel38/readonly_save_filters.png)

Now filter preferences can be saved in Errata if you have a
read-only account.  Other user accounts were not affected by this bug.

For more information, please see
[bug 1066247](https://bugzilla.redhat.com/show_bug.cgi?id=1066247).

### New QuarterlyUpdate form keeps values on validation error

When filing a new QuarterlyUpdate release, the product and release selector
would not preserve their state after a validation error and the user would
have to reselect the values to proceed.

Errata 3.8 keeps the product and release selector consistent with the
initial choices, making users more productive when filing advisories.

For more information, please see
[bug 1025602](https://bugzilla.redhat.com/show_bug.cgi?id=1025602).

### Bugs can be added to FAST releases without ACL checking

Advisories for Fast releases don't undergo the same bug eligibility checks
as QuarterlyUpdate or ZStream releases. Previously, Errata Tool incorrectly
applied ACL checks to bugs in these advisories.  This has been fixed.

For more information, please see
[bug 1066786](https://bugzilla.redhat.com/show_bug.cgi?id=1066786).

### Don't allow creation of more than one advisory for a X.Y update

When creating a new Y-Stream advisory, Errata Tool would incorrectly allow the
creation of multiple advisories for a single package.

In Errata Tool 3.8 this is fixed. It will now let the person filing the
second advisory know that an appropriate advisory already exists, and
the new bug should be added to it rather than creating a duplicate advisory.

Administrators may opt-out of this restriction on a per-release basis on
the release administration page:

[![allow_multiple_advisories_per_package.png](images/rel38/allow_multiple_advisories_per_package.png)](images/rel38/allow_multiple_advisories_per_package.png)

For more information, please see [bug
236947](https://bugzilla.redhat.com/show_bug.cgi?id=236947).

### Remove impact when converting from RHSA to RHBA

RHSA advisories in Errata Tool contain a security impact (such as 'Low' or
'Moderate') in their synopsis.

Previously, when converting an RHSA into a different type of advisory,
the impact would remain in the advisory synopsis.  Users had to remember to
manually remove the impact.

In Errata Tool 3.8, the security impact string is always removed from an
advisory's synopsis when converting from RHSA to a different type.

For more information, please see [bug
920907](https://bugzilla.redhat.com/show_bug.cgi?id=920907).

### Prevent non-secalert users from filing an RHSA via the API

The API for creating advisories in previous versions of Errata Tool was not
properly applying all user permission rules and hence it was possible for a
non-secalert user to file a security advisory. This has been fixed in Errata
Tool 3.8.

For details see [bug
1035078](https://bugzilla.redhat.com/show_bug.cgi?id=1035078).

### Restrict docs approval permissions

Previously users without the `docs` role were incorrectly able to approve
docs. This has been fixed in Errata Tool 3.8. Only users with the `docs`
role can approve the docs for an advisory.

For more details, please see [bug
990048](https://bugzilla.redhat.com/show_bug.cgi?id=990048).


Developer Related Improvements
------------------------------

### Adding and removing builds with the HTTP API

We have improved the HTTP API &mdash; introduced in Errata Tool 3.6 &mdash; to allow
adding and removing brew builds.  The response of every API call is JSON
encoded. The API methods are documented in our [API
documentation](http://apidocs.errata-devel.app.eng.bos.redhat.com/current/Api/V1/ErratumController.html)

For more information see [bug
1028222](https://bugzilla.redhat.com/show_bug.cgi?id=1028222).

### Additional command line options for live_rhn_push

This release provides more command line options for `live_rhn_push.rb`.
The patch was provided by Dennis Gregorovic. The following new options are
available:

* `--no-date-update` - will not update `update_date` or `issue_date` of the advisory.
* `--reset-update-date` - Sets the `update_date` to be the same as the issuing date.
* `--minimal` - Will only push the metadata and file, but not perform other operations.

Further information can be found on [bug
1060586](https://bugzilla.redhat.com/show_bug.cgi?id=1060586).


Team Changes
------------

There were no team changes during the Errata Tool 3.8 release cycle,
however this release is the first to contain large contributions from the
newer team members, Rohan (<rmcgover@redhat.com>) and Hao (<hyu@redhat.com>),
and it marks the last release (for now at least) with Jon Orris
(<jorris@redhat.com>) as lead developer. Jon is moving over to join John Lockhart
on the TPS development team.


What's Next
-----------

### Errata Tool 3.8.z

There are one or two remaining requirements for doing TPS-QA testing with
the new Pulp/CDN distribution channels. The ET team is working with the TPS
team and RCM to meet these requirements. Currently we intend to release the
extra functionality in one or more 3.8.z releases as soon as it is ready.

Should there be any RHEL-7 related requirements they will also be released
as soon as possible in a 3.8.z release.

### Errata Tool 3.9

Errata Tool 3.9 development is well underway. A number of bugs and RFEs are
already in POST ready to be merged and moved to ON_QA.

The planning and backlog for Errata Tool is managed in Bugzilla. For details
see [Errata Tool Bug
Lists](https://docs.engineering.redhat.com/display/HTD/Errata+Tool+Bug+Lists).

If you are interested in being involved in Errata Tool planning please subscribe
to `errata-dev-list@redhat.com`.

<!--
(Put an X in column 1 if it's mentioned above.
Put a dash if it's a regression and hence can be skipped.)

X 236947  ET should not allow more than one advisory for a given X.Y update
X 485395  ET: removal of brew build should mark associated rpmdiff runs as obsolete
  768999  [RFE] Support products shipped via CDN (TPS specific changes)
X 920907  Remove impact when convertingfrom RHSA to RHBA
X 965922  [RFE] Further speed improvements to docs queue
X 990048  Non Docs user can approve/disapprove docs
X 993127  [RFE] If automatic TPS runs disabled, QE owner should be able to schedule the run via ET manually
  996238  [RFE] Support shipping a package to multiple products in 1 advisory
X 1004895 [RFE] Pulp integration needs additional checksum type
X 1007511 Only change Rebase Bugs to ON_QA when errata is changed to QE
X 1012710 Trying to import a very large number of released builds fails with a server error
X 1012774 Errata schedules only half of TPS runs
X 1017918 Refresh of ACL and bug list takes too long in RHEL-7.0
X 1025602 New qu form forgets its values on validation error
  1026114 For CDN only advisory there's no link to the push page
  1026559 Can sometimes get an exception on 'add bugs to errata' page
  1026608 [DOC]Link of "Errata Tool Product Page"" should be updated in user guide"
X 1028222 (JSON) API functionality to add/remove builds.
X 1030548 RFE: display reboot_suggested attribute in UI
  1030826 ET does not respect errata release date and switches the state to PUSH_READY
  1031884 Bugs not closing on CDN only push
X 1033382 RFE: Show a list of optional channel to layered map in admin pages
X 1035078 Looks like non-security team members can file RHSA advisories via the new api
  1036043 Update the link of "Advisory Acceptance Criteria"""
  1050734 Incorrect counts or displayed bugs in Bug Coverage / qublockers table
  1050759 Add a 30 minute delay before scheduling tps-rhnqa jobs after a push
  1054027 The added user won't disappear in the input box in Edit CC list page
  1055955 ET couldn't break long lines when updating long comments without space added
  1056847 Typo for word "Engineering"" in role description page"
  1057437 Code clean-up: Remove all occurrences of Settings.cdn_enabled
X 1060586 Extra rhn push task flags plus ability to reset updated date to issue date
- 1063127 Product versions are wrapped to the bottom in products page
  1063135 Packages are shown in incorrect channel sections if trying to sort by layered channel in optional layered map page
  1063146 [Regression]Traceback when filing new advisory without type selected
  1063524 [RFE] Add filter option to exclude RHEL-7 advisories
  1063531 CDN/RHN Push blocker logic seems to be a bit broken
  1064171 NoMethodError undefined method 'can_push_cdn_stage?' error when push to RHN
X 1065809 [RFE] Allow non-admin users to sync component list from bug troubleshooter page
X 1066247 Readonly user can't save a filter
  1066412 Cdn repo can be created with empty name
X 1066786 Looks like bug eligibility rules incorrectly prevent adding bugs to FAST release
  1067901 [Regression] Errata Tool does not inform of approved docs
  1069044 Delayed Job tracker and completion notification mechanism
  1069485 [Regression]404 error on default solutions edition from admin page
  1069491 No corresponding cdn repos listed in channel page
  1069973 "Push to CDN"" item is not shown as pass after CDN push completed in advisory summary page"
  1069974 wrong argument (NilClass)! (Expected kind of OpenSSL::SSL::SSLContext).
? 1069977 [Regression]RHN staging push item not marked as PASS after RHN staging push completed
  1070560 Builds can be removed from no-NEW_FILES advisory using API
- 1070664 [Regression]TestOnly bugs with wrong status are shown as eligible when creating a Y-stream advisory
- 1070665 [Regression]Ineligible bugs should be shown without strikethough and  append  link  Why ineligible?
X 1067483 modifed bugs are not switched to on_qa
-->
