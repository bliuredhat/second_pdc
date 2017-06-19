Release Notes for Version 3.3
=============================

Overview
--------

Release 3.3 is the third minor release for Errata Tool 3 and is currently
scheduled to be deployed to production on April 24, 2013. It contains new
functionality and bug fixes.

Release 3.3 is smaller than recent releases and is focussed more on bug fixes
than RFEs. During the development period time was allocated to a redesign and
restructure of the Errata Tool documentation.

The first version of the redesigned documentation will be released in
conjunction with Errata Tool 3.3 and will serve as a starting point for
eventual completion of a full and complete set of Errata Tool docs.

### Related Resources

* [PRD document for Errata Tool Release 3.3](https://dart.qe.lab.eng.bne.redhat.com/RAP/en-US/Errata_Tool/3.3/html/PRD/index.html)

* [Bug List for Errata Tool Release 3.3](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.3%2B)


Security Improvements
---------------------

### Prevent removal of security tracking bugs by non-SRT users (FR1)

Removing a security bug from an RHSA has major implications for CVE tracking,
and can cause problems if it is done unexpectedly. For that reason, in Errata
Tool 3.3, removing security bugs can only be done by a member of the Security
Response Team. Non-SRT users will be prevented from removing security tracking
bugs.

You can see this new behaviour in operation in [this
screencast](https://errata-devel.app.eng.bos.redhat.com/screencasts/rel3.3/security-bug-removal.webm).

These screenshots show a non-SRT user being prevently from dropping a security
bug:
[![cannotdrop](images/rel33/cannotdrop.png)](images/rel33/cannotdrop.png)
[![onlysecteam](images/rel33/onlysecteam.png)](images/rel33/onlysecteam.png)

See [Bug 915556](https://bugzilla.redhat.com/show_bug.cgi?id=915556) for more
details.

UI Improvements
---------------

### Provide explanation on how to request RPMDiff waivers

RPMDiff test failures require waiving (or fixing) before an advisory can
continue to the QE state. For some advisories RPMDiff failures can be waived
only by users belonging to certain roles, for example members of the Security
Response Team, or members of Release Engineering.

Prior to Errata Tool 3.3 a developer reviewing a RPMDiff test failure was
presented with a a short message such as "Only secalert team can waive" and no
further explanation about how to do that.

In Errata Tool 3.3 this is addressed. As well as the message explaining which
users are able to waive this test result, there is also:

* a mailto link which will send an email to the applicable RT queue containing
  pre-populated details about the advisory, the build and the test that
  requires waiving, as well as links to the test result in Errata Tool,

* a note explain which IRC channel members of the required role can be
  contacted, and

* a link to a page showing all the users who have the required role in Errata
  Tool.

The new waive request explanation is shown below:

[![waiveexplanation](images/rel33/waiveexplanation.png)](images/rel33/waiveexplanation.png)

The pre-poplated email looks like this:

[![waiveemail](images/rel33/waiveemail.png)](images/rel33/waiveemail.png)

Currently the Releng and Secalert roles are the ones with an IRC channel and
RT queue email populated. The mechanism is generic though, so other Errata
Tool roles can have similar details added as required.

You can see this new behaviour in operation in
[this screencast](https://errata-devel.app.eng.bos.redhat.com/screencasts/rel3.3/rpmdiff-waiver-request-2.webm).

For more details see
[Bug 674454](https://bugzilla.redhat.com/show_bug.cgi?id=674454).

### Enhanced "flash" messages

A flash message is a message that appears near the top of the page after the
user has taken some action. It generally confirms that the action was
successful or lets the user know if something went wrong.

Prior to the major UI update in Errata Tool 2.3 flash messages were plainly
formatted regardless of what type of notice they were. The updated UI
distinguishes between 'notice', 'alert' and 'error' messages and
displays them an appropriately colored box.

However, since Errata Tool was still incorrectly using 'notice' for every
flash message, in meant that failure messages and errors were appearing in a
misleading green box.

Errata Tool 3.3 addresses this by:

* improving the mechanism for displaying flash messages, and making it
  consistent for all types of messages,

* adding a small icon to the message display to provide an additional visual
  indication of the type of the message, and

* updating all the places where messages are created so that they use the
  appropriate message type instead of just 'notice'

Some example flash messages are shown below:
[![errormessage](images/rel33/errormessage.png)](images/rel33/errormessage.png)
[![successmessage](images/rel33/successmessage.png)](images/rel33/successmessage.png)

You can see a demo of the new flash messages in [this
screencast](https://errata-devel.app.eng.bos.redhat.com/screencasts/rel3.3/flash-notices.webm)
or you can try them out yourself at [this test
page](https://errata-devel.app.eng.bos.redhat.com/errata/test_flash_notices).

For more information see [Bug 885856](https://bugzilla.redhat.com/show_bug.cgi?id=885856).

### New "News" menu

For Errata Tool users who are not subscribed to the mailing list, there is no
convenient way to get notified about updates to Errata Tool, or other
important announcements. To address this the "News" menu was added. This is
available in the top menu next to "Help".

The news items are populated via RSS feed from the Errata Tool news blog on
the HSS portal. There is a mechanism for alerting users to new items in the
news menu by showing a count of unread items, for example `News (2)` indicates
there are two new items available since the last time the user looked at the
news menu. (This is implemented using a cookie).

This shows the menu as it might appear with one unread item:
[![newmenu](images/rel33/newsmenu.png)](images/rel33/newsmenu.png)

The News menu shipped already in Errata Tool 3.2.1.

For more information see
[Bug 887081](https://bugzilla.redhat.com/show_bug.cgi?id=887081).

Documentation Updates
---------------------

The Errata Tool documention has been restructured as part of the Errata Tool
Documentation project. This is the first release where the release notes are
in their own separate book. We also have a new Developer Guide.

You can read more about the documentation project over in
[Part 1 of the Developer Guide](https://errata.devel.redhat.com/developer-guide/pt01.html)
or see these posts on the mailing list about
[documentation updates](http://post-office.corp.redhat.com/archives/errata-dev-list/2013-April/msg00006.html),
[the new proposed outline](http://post-office.corp.redhat.com/archives/errata-dev-list/2013-April/msg00007.html),
and [contributing](http://post-office.corp.redhat.com/archives/errata-dev-list/2013-April/msg00008.html).

Other Items
-----------

The following RFEs and bug fixes are also included in Errata Tool 3.3:

*   [Bug 863086](https://bugzilla.redhat.com/show_bug.cgi?id=863086)
    Display approval restriction to permitted users too

*   [Bug 921160](https://bugzilla.redhat.com/show_bug.cgi?id=921160)
    Errata tool "User Access Required" page has broken link to "Errata Tool Roles" in request access steps

*   [Bug 928133](https://bugzilla.redhat.com/show_bug.cgi?id=928133)
    Button to reschedule one rpmdiff run is no longer shown in the UI

*   [Bug 924429](https://bugzilla.redhat.com/show_bug.cgi?id=924429)
    Wrong URL to page with organization tree as unprivileged user

*   [Bug 924034](https://bugzilla.redhat.com/show_bug.cgi?id=924034)
    The 'News' menu doesn't work if you are not signed in

*   [Bug 881649](https://bugzilla.redhat.com/show_bug.cgi?id=881649)
    Wrong TPS job reschedule email notification

The following bug fixes have already been shipped in Errata Tool 3.2.1 or
3.2.2.

*   [Bug 921325](https://bugzilla.redhat.com/show_bug.cgi?id=921325)
    Create suitable workflow rule set for internal products and ensure internal advisories use it

*   [Bug 921256](https://bugzilla.redhat.com/show_bug.cgi?id=921256)
    Errata pushed comment is now private, needs to be public

*   [Bug 923528](https://bugzilla.redhat.com/show_bug.cgi?id=923528)
    Relocate clean_backtrace method so XmlrpcController can see it

*   [Bug 923404](https://bugzilla.redhat.com/show_bug.cgi?id=923404)
    Errata /get_tps_txt output is missing trailing newline

*   [Bug 921681](https://bugzilla.redhat.com/show_bug.cgi?id=921681)
    /errata/blocking\_errata\_for and depending\_errata\_for are redirecting to HTTPS

*   [Bug 921000](https://bugzilla.redhat.com/show_bug.cgi?id=921000)
    Seems that ET is adding random comment authors

*   [Bug 889041](https://bugzilla.redhat.com/show_bug.cgi?id=889041)
    Don't ignore mail delivery failure when sending 'request signatures' email

What's Next?
------------

The main focus for the next release of Errata Tool (version 3.4) is going to
be improving the UI for managing products, releases, product versions,
channels, variants, (etc). The goals are to make it easier to use, more
consistent and to make it easier get things like new products and channels set
up correctly.

(If you are interested in this then cc youself on
[Bug 952445](https://bugzilla.redhat.com/show_bug.cgi?id=952445)).
