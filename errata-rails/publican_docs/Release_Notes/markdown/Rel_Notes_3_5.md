Release Notes for Version 3.5
=============================

Overview
--------

Release 3.5 is the fifth minor release for Errata Tool 3. It contains new
functionality and bug fixes.

This release is the first release of Errata Tool with QE done by the HSS QE
team, consisting of Joyce Zhang and Shan Jiang, the first release with
contributions from new developer Roman Joost and the second release with
product owner/team leader Jason McDonald.

### Related Resources

* [Bug List for Errata Tool Release 3.5](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.5%2B)


UI Improvements
---------------

### Admin UI Improvements

Errata Tool 3.5 includes the first part of a planned overhaul of the
administration UI. The goals of the UI changes are to make it easier to read,
navigate and understand the relationships between the different elements such
as products, product versions, variants, channels, etc, and to provide a more
consistent look and feel for viewing and editing them.

So far the new UI is implemented for products and product versions only. There
are reusable components that should make it easy to extend to the other
elements in future releases.

[![admin1](images/rel35/admin1.png)](images/rel35/admin1.png)

[![admin2](images/rel35/admin2.png)](images/rel35/admin2.png)

See [Bug 952445](https://bugzilla.redhat.com/show_bug.cgi?id=952445) for more
details.

### Flash Notice Improvements

Certain AJAX based actions performed in Errata Tool would dynamically display
a notice to users either confirming the operation's success or informing the
user if something went wrong.

This notice would be displayed in the same place as the conventional
non-dynamic notices, which is near the top of the page. The problem with this
is that on a long page the notice is not visible if you are scrolled down any
amount. To see the notice you would have to scroll up. This was particularly
an issue on the Docs Queue pages when changing the assigned docs reviewer for
an advisory.

To address this issue Errata Tool notices are now always visible on screen
even when the user is scrolled down on a long page and will maintain their
position even as the page is scrolled up and down. This behaviour is
demonstrated in **[this
screencast](https://errata-devel.app.eng.bos.redhat.com/screencasts/rel3.5/new_errata_flash_messages.webm)**.

Here's how it looks when updating a docs reviewer on the Docs Queue page.

[![notices](images/rel35/notices.png)](images/rel35/notices.png)

See [Bug 969893](https://bugzilla.redhat.com/show_bug.cgi?id=969893) for more
details.

### Calendar Date Picker For Entering Dates

To make it easier to enter dates such as embargo dates and release dates, a
calendar style date picker is now provided. Also the date validation is
improved so that if an invalid date is entered then a validation error is
displayed (instead of being silently ignored).

[![datepicker](images/rel35/datepicker.png)](images/rel35/datepicker.png)

See [Bug 990010](https://bugzilla.redhat.com/show_bug.cgi?id=990010) for more
details.

### 'Add me to CC list' Option When Commenting

When adding a comment to an advisory it is often the case that you want to get
email notifications on follow-ups or replies to your comment. There is now a
checkbox that let's you add yourself to the cc-list when submitting a comment.

[![addme](images/rel35/addme.png)](images/rel35/addme.png)

See [Bug 704602](https://bugzilla.redhat.com/show_bug.cgi?id=704602) for more
details.

Release Process Improvements
----------------------------

### Disallow RHN stage push before dependencies are pushed

Advisories that depend on other advisories are prevented from moving to
REL\_PREP before their dependencies, and hence can't be pushed live before
their dependencies are pushed live.

However, pushes to RHN stage were not being subjected to the same restriction.
This allowed advisories to be pushed to RHN stage before their dependencies,
which in some cases resulted in RHNQA TPS failures due to unmet dependency
requirements.

In Errata Tool 3.5 an advisory can't be pushed to RHN stage unless its
dependencies are pushed there first.

See [Bug 902226](https://bugzilla.redhat.com/show_bug.cgi?id=902226) for more
details.

### Prevent Moving Advisory From non-FAST to FAST Release

There are rules governing which bugs can be shipped in which releases. Moving
an advisory from an X.Y release to an X.Y FAST release can cause those rules
to be bypassed. So Errata Tool release 3.5 prevents this from happening.

See [Bug 874158](https://bugzilla.redhat.com/show_bug.cgi?id=874158) for more
details.

Security Related Improvements
-----------------------------

### Tightened Restrictions On Viewing Embargoed Advisories

To reduce the chance of leaking sensitive information, Errata Tool users with
the 'readonly' role are not permitted to view embargoed advisories. However,
it was still possible to see the embargoed advisories in the advisory list
views and hence know they exist and what their name is plus some other details
visible in the advisory list view.

In Errata Tool release 3.5 embargoed advisories will not be visible in
advisory lists for users who do not have permission to view them.

Additionally users who have an Errata Tool account but don't have a specific
role assigned to them will be treated the same as 'readonly' users and hence
won't be able to view embaroed advisories. This is to simplify the [account
creation policy instructions](https://errata.devel.redhat.com/user-guide/requests-ticket-triage-procedures.html#requests-account-creation-policyprocedure)
and reduce the risk of accidentally giving access to embargoed advisories to
users who should not have it.

See [Bug 978633](https://bugzilla.redhat.com/show_bug.cgi?id=978633) and
[Bug 994808](https://bugzilla.redhat.com/show_bug.cgi?id=994808) for more
details.

Process Improvements
--------------------

### Jenkins

A Jenkins instance is now being used to do continuous integration for Errata
Tool.  It automatically runs the test suite whenever a patch is pushed to
Gerrit and sends a notification on IRC when a patch results in a test failure.
This is a convenient way to be notified sooner when something is broken.

[![jenkins](images/rel35/jenkins.png)](images/rel35/jenkins.png)

### QE

Errata Tool is now fortunate to have the services of a HSS QE team. The QE
team are responsible for creating and maintaining TCMS test cases for Errata
Tool bugs and RFEs and for performing QE on the bugs and RFEs before they are
released to production. It's already clear that the introduction of the QE
process has been successful and is providing considerable benefit to the
quality of Errata Tool releases.


Full List of Bug Fixes and RFEs
-------------------------------

### Errata Tool 3.5

The following bug fixes and RFEs were shipped in Errata Tool release 3.5:

* [Bug 998900](https://bugzilla.redhat.com/show_bug.cgi?id=998900) -
  Exception occurs when creating an advisory and there is no release selected

* [Bug 994808](https://bugzilla.redhat.com/show_bug.cgi?id=994808) -
  User with no roles should be treated the same as a readonly user

* [Bug 993533](https://bugzilla.redhat.com/show_bug.cgi?id=993533) -
  Undefined method 'variant\_cdn\_repos\_path' when viewing variants list

* [Bug 993430](https://bugzilla.redhat.com/show_bug.cgi?id=993430) -
  Old /errata/show/:id urls should redirect to /advisory/:id (and make sure it works for 'readonly' users)

* [Bug 991541](https://bugzilla.redhat.com/show_bug.cgi?id=991541) -
  RFE: Restrict TPS WAIVE button to QE+Admin roles

* [Bug 991255](https://bugzilla.redhat.com/show_bug.cgi?id=991255) -
  Configure Development Errata Tool with Environment Variables

* [Bug 990075](https://bugzilla.redhat.com/show_bug.cgi?id=990075) -
  Could not create advisories using existing advisory or manually

* [Bug 990010](https://bugzilla.redhat.com/show_bug.cgi?id=990010) -
  Using datepicker for user to select a date instead of inputting a date manually

* [Bug 990002](https://bugzilla.redhat.com/show_bug.cgi?id=990002) -
  Create a blank RHEL version causes exception

* [Bug 989864](https://bugzilla.redhat.com/show_bug.cgi?id=989864) -
  Create a channel without name inputted causes exception

* [Bug 989825](https://bugzilla.redhat.com/show_bug.cgi?id=989825) -
  ET should have a link back to product version when it's in list all channels page

* [Bug 987691](https://bugzilla.redhat.com/show_bug.cgi?id=987691) -
  Undefined local variable or method 'bugs' in bugs/for\_errata

* [Bug 987573](https://bugzilla.redhat.com/show_bug.cgi?id=987573) -
  Improve Bugzilla feedback on invalid bugs

* [Bug 985227](https://bugzilla.redhat.com/show_bug.cgi?id=985227) -
  Empty comment can be added to an advisory

* [Bug 984760](https://bugzilla.redhat.com/show_bug.cgi?id=984760) -
  Nil product when creating variant causes exception

* [Bug 984598](https://bugzilla.redhat.com/show_bug.cgi?id=984598) -
  signatures not displaying on Builds tab

* [Bug 983820](https://bugzilla.redhat.com/show_bug.cgi?id=983820) -
  The chosen tab is not highlighted in docs queue page

* [Bug 982926](https://bugzilla.redhat.com/show_bug.cgi?id=982926) -
  Test Harness: Allow tester to change between users with different roles

* [Bug 982828](https://bugzilla.redhat.com/show_bug.cgi?id=982828) -
  Exception notifications should go to an email alias

* [Bug 978637](https://bugzilla.redhat.com/show_bug.cgi?id=978637) -
  Test harness to simulate events and external systems to progress an advisory in test/QE environments

* [Bug 978633](https://bugzilla.redhat.com/show_bug.cgi?id=978633) -
  Read-only users should see redacted version of embargoed advisory in advisory lists

* [Bug 978604](https://bugzilla.redhat.com/show_bug.cgi?id=978604) -
  Cache rhsa\_map\_cpe data

* [Bug 978249](https://bugzilla.redhat.com/show_bug.cgi?id=978249) -
  Bad links on CPE management page

* [Bug 978077](https://bugzilla.redhat.com/show_bug.cgi?id=978077) -
  Changing an advisory's release should check if the workflow rule set needs to change also

* [Bug 977209](https://bugzilla.redhat.com/show_bug.cgi?id=977209) -
  Rake task to create text for HSS portal release announcement from boilerplate

* [Bug 976665](https://bugzilla.redhat.com/show_bug.cgi?id=976665) -
  Regression in selftest results for ET 3.4

* [Bug 976119](https://bugzilla.redhat.com/show_bug.cgi?id=976119) -
  Can't remove a variant (gives 404 error)

* [Bug 973644](https://bugzilla.redhat.com/show_bug.cgi?id=973644) -
  Update OVAL creation CPE list to better support SCAP

* [Bug 973557](https://bugzilla.redhat.com/show_bug.cgi?id=973557) -
  Intermittent auth failure creating Covscan runs (Covscan XMLRPC error)

* [Bug 969893](https://bugzilla.redhat.com/show_bug.cgi?id=969893) -
  On long pages like the docs queue dynamic confirmation messages are often not visible

* [Bug 968233](https://bugzilla.redhat.com/show_bug.cgi?id=968233) -
  JSON api for show\_released\_build should list all errata for build

* [Bug 966287](https://bugzilla.redhat.com/show_bug.cgi?id=966287) -
  Sometimes we get an AbstractController::DoubleRenderError in bugs#updatebugstates

* [Bug 965382](https://bugzilla.redhat.com/show_bug.cgi?id=965382) -
  Duplicates in package list

* [Bug 962500](https://bugzilla.redhat.com/show_bug.cgi?id=962500) -
  Bug Troubleshooter: Handle empty approved component list (plus new check list class refactor)

* [Bug 952445](https://bugzilla.redhat.com/show_bug.cgi?id=952445) -
  [RFE] More consistent and understandable UI for managing products/releases/channels etc

* [Bug 947948](https://bugzilla.redhat.com/show_bug.cgi?id=947948) -
  \[RFE\]: separate hosts between good | bad | all

* [Bug 920891](https://bugzilla.redhat.com/show_bug.cgi?id=920891) -
  Our devel ET server should accept the Red Hat SSL cert for connecting to non-prod bugzilla instances

* [Bug 910420](https://bugzilla.redhat.com/show_bug.cgi?id=910420) -
  [RFE] Remove warnings on missing descriptions of tracking CVE BZs

* [Bug 902226](https://bugzilla.redhat.com/show_bug.cgi?id=902226) -
  ET should not allow push to ErrataStage if erratas dependencies are not pushed

* [Bug 874158](https://bugzilla.redhat.com/show_bug.cgi?id=874158) -
  Prevent switch from X.Y to X.Y FAST release

* [Bug 866426](https://bugzilla.redhat.com/show_bug.cgi?id=866426) -
  Improve handling of the CVE list field

* [Bug 866375](https://bugzilla.redhat.com/show_bug.cgi?id=866375) -
  Add Bugs does not seem to be working for bugs (with blocker flag set)

* [Bug 704602](https://bugzilla.redhat.com/show_bug.cgi?id=704602) -
  RFE: Add a "Add me to CC List" box, BZ-style, to the New Comment area.

* [Bug 695726](https://bugzilla.redhat.com/show_bug.cgi?id=695726) -
  Test-plan input validation

* [Bug 636977](https://bugzilla.redhat.com/show_bug.cgi?id=636977) -
  Cloning erratum doesn't clone everything


### Errata Tool 3.4-z

The following bug fixes were shipped in Errata Tool releases 3.4-1.0, 3.4-2.0 and
3.4-3.0:

* [Bug 986748](https://bugzilla.redhat.com/show_bug.cgi?id=986748) -
  The /docs/list displays "Can't parse flag " q"" and no errata

* [Bug 983932](https://bugzilla.redhat.com/show_bug.cgi?id=983932) -
  Cannot display build list for texlive package

* [Bug 983405](https://bugzilla.redhat.com/show_bug.cgi?id=983405) -
  [RFE] Add capability for admins to reschedule failed Covscan runs

* [Bug 976378](https://bugzilla.redhat.com/show_bug.cgi?id=976378) -
  Undefined variable errata in brew#remove\_build

* [Bug 976303](https://bugzilla.redhat.com/show_bug.cgi?id=976303) -
  Incorrect number of current coverity test runs displayed

* [Bug 976115](https://bugzilla.redhat.com/show_bug.cgi?id=976115) -
  NoMethod error in tps#check\_for\_missing\_rhnqa\_jobs

* [Bug 976099](https://bugzilla.redhat.com/show_bug.cgi?id=976099) -
  In brew#preview\_files: undefined method 'concat' for HashList

* [Bug 975818](https://bugzilla.redhat.com/show_bug.cgi?id=975818) -
  change default sorting in list of external test runs

* [Bug 975295](https://bugzilla.redhat.com/show_bug.cgi?id=975295) -
  Don't update covscan current flag based on scan status changes


What's Next
-----------

Planning for Errata Tool 3.6 is underway. The currently proposed functionality
includes upgrading to Ruby 1.9 and Rails 3.2, improved JSON API for creating
and managing advisories and better support for SCL advisories.

Please subscribe to the errata-dev-list if you want to hear more about the
planning for Errata Tool 3.6.
