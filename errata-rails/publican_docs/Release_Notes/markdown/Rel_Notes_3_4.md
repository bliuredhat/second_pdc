Release Notes for Version 3.4
=============================

Overview
--------

Release 3.4 is the fourth minor release for Errata Tool 3 and is currently
scheduled to be deployed to production in mid June, 2013. It contains new
functionality and bug fixes.

### Related Resources

* [Bug List for Errata Tool Release 3.4](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.4%2B)


Documentation Improvements
--------------------------

### Improved Docs Queue Speed

The Errata Tool Docs Queue page tends to be quite slow to load. In Errata 3.4
there were two significant changes made to address this.

The first is to refactor the way that the system decides which Docs
Responsibility tabs to show on that page. It shows only the Docs
Responsibilities that currently have at least one advisory in the Docs Queue.
Previously the way this was done was fairly inefficient and performed a
separate query on the Errata table for each Docs Responsibility. This has been
refactored so that just a single database query is used.

The second is to change the way that the 'Edit Reviewer' modal dialog was
rendered in the page. Now there is just one modal dialog element in the DOM
that gets populated dynamically when the user clicks on the Edit Reviewer
button. Previously the modal dialog was created statically for each row in
the docs queue. This made the page itself significantly longer and increased
the browser render time unnecessarily.

These improvements made the page load somewhere in the order of 20% faster. It
is still slower than is desirable due to the way it calculates and
displays a count of the bugs with and without completed Doc Text for each
advisory in the Docs Queue. Some ways to improve this further have been
discussed and will be investigated further in a future release.

See [Bug 870163](https://bugzilla.redhat.com/show_bug.cgi?id=870163) for more
details.

### Use 'requires_doc_text' flag to track and manage advisory documentation

An advisory's text includes release notes and a description for each bug fixed
in an advisory. Engineering Content Services are responsible for preparing,
collating and editing this information before the advisory is released.

Previously the Bugzilla flags `requires_release_note`, `skip-errata` and
`technical_note` were used in combination to track the status of the
documentation for each bug. Recently the processes and workflow was reviewed
and simplified and the three flags were replaced with a single flag called
`requires_doc_text`.

In release 3.4, Errata Tool is now aware of this new flag and uses it to
display the status of each bug's documentation in the Doc Text Info page for
an advisory. This allows ECS to see quickly how much work is remaining and
which bugs still require documentation. The obsolete flags are no longer
shown.

Additionally there are some UI improvements, a new display of bug counts and
percentages broken down by the status of the flag in both the Doc Text Info
page and the Docs Queue pages, and a terminology update to reflect the new
usage. (Previously the 'Doc Text Info' page was known as the 'Tech Note Info'
page).

[![003](images/rel34/003.png)](images/rel34/003.png)

See [Bug 909759](https://bugzilla.redhat.com/show_bug.cgi?id=909759) for more
details.

### Other Docs Improvements

A few other enhancements were made to the Docs Queue page and the updated Doc
Text Info page.

Visited links are now showing in a different colour. This is so ECS team members
can use the color difference as an informal indication of work remaining.

The Doc Text Info page now shows the bug modified date. This is useful
since bugs that have been updated might have had the doc text updated in
bugzilla, or might require reviewing for other reasons.

There is now a visual indication of which column is currently being used to
sort the tables.

See [Bug 852562](https://bugzilla.redhat.com/show_bug.cgi?id=852562) for more
details.


Security Improvements
---------------------

### Prevent CVEs from being removed by non-security users

Removing a CVE from an advisory has many implications related to security
alerts and CVE tracking. For this reason only a member of the security response
team is permitted to remove a CVE from an advisory. This is related to the
restriction on removing security bugs from an advisory which was shipped in
Errata Tool 3.3.

See [Bug 952984](https://bugzilla.redhat.com/show_bug.cgi?id=952984) for more
details.


Covscan Improvements
--------------------

### Obsoleting Coverity Scans

When updating an advisory's brew build from an older build to a newer build
Errata Tool was not automatically obsoleting the Coverity scan for the older
build. Because the older (possibly not passed) scan was still considered
active it was causing in some cases an "advisory has not passed all external
tests" message even when the newer scan had passed successfully.

This is fixed in Errata Tool 3.4. Now Coverity scans are obsoleted when an
advisory's brew build is superceded by a newer one.

See [Bug 959008](https://bugzilla.redhat.com/show_bug.cgi?id=959008) for more
details.

This fix was actually shipped in Errata Tool 3.3.1.

### Show 'current' scans separate from 'non-current' scans

Previously active and inactive scans were shown together in one list. Since the
active scans are more relevant they are now shown separately at the top while
old scans are shown at the bottom.

### Recognise new INELIGIBLE response when creating a Coverity scan

Previously when an rpm was classified as inelegible for scanning by Covscan
it was treated as an error and the scan record in Errata Tool was flagged as
inactive. Covscan now responds with the status INELIGIBLE. INELIGIBLE scans
remain active in Errata Tool and are treated the same as passed or waived
scans.

See [Bug 970350](https://bugzilla.redhat.com/show_bug.cgi?id=970350) for more
details.

### Properly re-activating scans that were previously marked inactive

If Errata Tool attempts to schedule a Coverity scan and it fails for whatever
reason, the scan's record in Errata Tool is marked as 'inactive' or 'non-current'.

In the case where that scan is restarted by Covscan, perhaps after
the cause of the failure has been fixed, Errata Tool would update the scan
with the new status, but would not flag the scan as 'current'.

This is fixed in Errata Tool 3.4. When a previously failed scan is restarted
the 'current' flag will be set as appropriate.

See [Bug 971275](https://bugzilla.redhat.com/show_bug.cgi?id=971275) for more
details.

### Allow a Covscan to be rescheduled

Previously it was not possible to reschedule a Covscan via the web ui. In
Errata Tool 3.4 there is a link that allows scans to be rescheduled (where
it is permissable).

There are some restrictions on who can reschedule Covscans. In general they
can only be rescheduled if the scan wasn't submitted successfully, however
admin users are able to reschedule any scan where the brew build is still
current for the applicable advisory.

See [Bug 970354](https://bugzilla.redhat.com/show_bug.cgi?id=970354) for more
details.

(This screenshot shows the reschedule link, the INELIGIBLE status and the
separate list for current and non-current scans).

[![007](images/rel34/007.png)](images/rel34/007.png)

### Show a list of all Covscans

Prior to release 3.4 there was no way to show all Covscans. They were only
viewable via the Errata page. Errata Tool 3.4 includes a page to list all
Covscans. This is currently available to admin users only but in future it may
be more accessible.

See [Bug 962295](https://bugzilla.redhat.com/show_bug.cgi?id=962295) for more
details.


Other Improvements
------------------

### Improved Search Results

In Errata Tool if you use the search box in the top bar to search for some
text it will look for a match for that text in the advisory synopsis field.
In Errata Tool 3.4 the text search is integrated with the filter system rather
then implemented separately using different code. Now a text search is
eqivalent to a filter with something entered in the synopsis text field and
the output of the search results now looks the same as the advisory list that
you get when using a filter, rather than being a different format.

Additionally there is a new shorter url for searches. (The old url is
redirected to preserve any existing bookmarks).

See [Bug 957586](https://bugzilla.redhat.com/show_bug.cgi?id=957586) for more
details including a test procedure that can be followed to provide a
demonstration of the new behaviour.

### Show Brew Builds in the Summary Tab

The Summary tab now includes a list of brew builds. This lets you see the
builds conveniently without needing to visit the Builds tab. In the case where
there are a large number of builds, the list is abbreviated the same way that
the bug list is abbreviated on the Summary page.

See [Bug 902019](https://bugzilla.redhat.com/show_bug.cgi?id=902019) for more
details.

[![009](images/rel34/009.png)](images/rel34/009.png)

### In brief Information show Devel Owner instead of Manager Contact

Because it's generally less useful the 'Manager Contact' is no longer shown on
the brief version of the Information panel. Instead the 'Package Owner' is
shown.

Also the 'Manager Contact' label is renamed to 'Package Owner Manager' which
better describes what it is.

See [Bug 962406](https://bugzilla.redhat.com/show_bug.cgi?id=962406) for more
details.

[![010](images/rel34/010.png)](images/rel34/010.png)

[![011](images/rel34/011.png)](images/rel34/011.png)

### Grouping and filtering in TPS job lists

TPS job lists were previously shown in a big flat list. There was no way to
easily group them by release. In Errata Tool 3.4 the TPS job lists can be
filtered by QE team, product or release and they are displayed grouped by
release and QE team.

See [Bug 676619](https://bugzilla.redhat.com/show_bug.cgi?id=676619) for more
details.

[![001](images/rel34/001.png)](images/rel34/001.png)

[![002](images/rel34/002.png)](images/rel34/002.png)


Bug Fixes & Minor RFEs
----------------------

The following bug fixes and minor RFEs were shipped in Errata Tool release 3.4:

* [Bug 499825](https://bugzilla.redhat.com/show_bug.cgi?id=499825) -
  The word 'BZ' is missing from the spell checker word list.

* [Bug 670818](https://bugzilla.redhat.com/show_bug.cgi?id=670818) -
  Provide access to important advisory dates via the JSON api.

* [Bug 875205](https://bugzilla.redhat.com/show_bug.cgi?id=875205) -
  Variant ID missing from channels API response.

* [Bug 878069](https://bugzilla.redhat.com/show_bug.cgi?id=878069) -
  New products should use the 'enterprise' default solution text.

* [Bug 888521](https://bugzilla.redhat.com/show_bug.cgi?id=888521) -
  Fix error when showing notification after adding many brew builds.

* [Bug 907422](https://bugzilla.redhat.com/show_bug.cgi?id=907422) -
  Misnamed checkbox label when creating or editing a Y-stream release.

* [Bug 908601](https://bugzilla.redhat.com/show_bug.cgi?id=908601) -
  Plain text email showing some html encoded quote characters.

* [Bug 914722](https://bugzilla.redhat.com/show_bug.cgi?id=914722) -
  Should clear the hostname when a TPS run is rescheduled.

* [Bug 916689](https://bugzilla.redhat.com/show_bug.cgi?id=916689) -
  Record comment showing build changes when moving from NEW\_FILES.

* [Bug 921580](https://bugzilla.redhat.com/show_bug.cgi?id=921580) -
  Don't invoke a pub task when updating bug states (after pushing live).

* [Bug 928923](https://bugzilla.redhat.com/show_bug.cgi?id=928923) -
  Add validations for creating RHEL variants.

* [Bug 956599](https://bugzilla.redhat.com/show_bug.cgi?id=956599) -
  Exception thrown when dropping an advisory.

* [Bug 957545](https://bugzilla.redhat.com/show_bug.cgi?id=957545) -
  Exception thrown when rescheduling a single rpmdiff.

* [Bug 958517](https://bugzilla.redhat.com/show_bug.cgi?id=958517) -
  Fix incorrect disallowing of modifications to bugs and CVEs in security
  advisories.

* [Bug 958856](https://bugzilla.redhat.com/show_bug.cgi?id=958856) -
  Broken formatting in notification messages due to missing line breaks.

* [Bug 958983](https://bugzilla.redhat.com/show_bug.cgi?id=958983) -
  Dropped advisories unable to remove bugs.

* [Bug 960734](https://bugzilla.redhat.com/show_bug.cgi?id=960734) -
  Error when removing a CDN repo mapping from a variant.

* [Bug 961157](https://bugzilla.redhat.com/show_bug.cgi?id=961157) -
  Allow creating an advisory using the Y-stream/guided even if generated
  description is over 4000 chars.

* [Bug 962262](https://bugzilla.redhat.com/show_bug.cgi?id=962262) -
  Incorrect color scheme when viewing user admin pages.

* [Bug 962654](https://bugzilla.redhat.com/show_bug.cgi?id=962654) -
  Expose documentation-related information via JSON.

* [Bug 964011](https://bugzilla.redhat.com/show_bug.cgi?id=964011) -
  Fix the 'Edit Reviewer' button in /docs/errata_by_responsibility pages.

* [Bug 966126](https://bugzilla.redhat.com/show_bug.cgi?id=966126) -
  Invisible (non-underlined) link to Bug Troubleshooter when editing advisory.

* [Bug 974979](https://bugzilla.redhat.com/show_bug.cgi?id=974979) -
  Transposed client/server typo OVAL query responses.
