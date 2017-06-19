Filing an Advisory
==================

Introduction
------------

This section describes the process of filing Red Hat errata advisories,
sometimes referred to as simply _errata_ or _advisories_. The expected target
audience is Engineering (package maintainers).

- Please become familiar with
  [RHEL Content Definition Workflow](https://mojo.redhat.com/docs/DOC-68397)
  before you start working on advisories.

- Asynchronous security advisories are filed by the
  [Product Security Team](https://mojo.redhat.com/groups/product-security),
  rather than by package maintainers, unless the impact of the security
  issue is low, in which case the advisory can be filed by a non-security
  user but will be subject to approval by the Product Security Team.

The Errata process is managed by the _Errata Tool_, which is located at
[errata.devel.redhat.com](https://errata.devel.redhat.com/). You need to have
an account in this tool; if you do not have it, you are given instructions on
how to have it created. Please follow the instructions and return here when
your account has been created.

The errata process has many steps, and several different departments are usually
involved.  The Engineering, Quality Engineering, Release Engineering and
Engineering Content Services teams all play significant roles. The current
status of every advisory can be seen in the Errata Tool as _Approval Progress_.

Are you ready?

Create a skeleton and submit a description
------------------------------------------

Click the _+ New Advisory_ button on the front page to start filing your
advisory:

[![step1](images/newerrata/newerratastep1.png)](images/newerrata/newerratastep1.png)

You are given two options:

[![step2](images/newerrata/newerratastep2.png)](images/newerrata/newerratastep2.png)

- If (and only if) you are filing a minor-update (Y-Stream) or Fastrack advisory, use the
  first option. An example of a minor update is RHEL 6.4 or 5.9. This option
  cannot be used for Z-Stream or any other asynchronous release which
  is not driven by an Approved Component List.

- If you are filing a Z-Stream or an
  asynchronous advisory, use the second option. (Fastrack errata may also
  be filed using this option, but the first option is generally preferred.)  
  **You cannot file a placeholder asynchronous advisory and then turn it into a
  minor-update advisory. The Errata Tool disallows such changes because that
  would circumvent the Approved Component List.**
  After selecting this option, you will be given the opportunity to clone an
  existing advisory.

    - If cloning an advisory, you must provide the ID of the advisory that you
      wish to use as a template for the new one, so a lot of boilerplate text
      will be created automatically and you will not have to write it, although
      you will still have to edit it.

    - If not cloning an advisory, you must write almost everything from scratch,
      so it is generally preferred to clone an advisory. In fact, you can use
      any advisory as a template, even if its component or major release
      differs. Still, the better template you choose, the less work will be
      required to polish the text.

Click on the most appropriate option. The following paragraphs describe the
options in detail.

### Assisted Create

A new form, _New Y-stream or Fast Track Advisory_, is displayed. It consists
of several fields:

- The _Product_ which the advisory will affect.
- The _Release_ which the advisory will affect.
- The advisory _Type_: Bug Fix, Enhancement or Security.
- The advisory _Impact_, only for a Red Hat Security Advisory.
- A list of eligible _Packages_.
- A list of ineligible _Packages_.

[![step3](images/newerrata/newerratastep3.png)](images/newerrata/newerratastep3.png)

Change the product, advisory type, release and impact as appropriate. Note that
when you change the value of product or release, the list of eligible packages
changes, too.

If your component is displayed in the list of packages that _have no bugs
eligible for this release_, click the package name and a list of its bugs will
be displayed. For each bug, there will be a link _Why?_, which leads
to a page on which you can see why the bug cannot be used.

If your component is not offered in the list, at all, click the help icon next
to _Select Available Packages_ and follow the instructions.  **Do not try to
file your advisory manually using another release, such as FAST6.4 instead of
RHEL-6.4.0. That is not a solution.** Reload the page when the problem has been
resolved.

If/when your component is offered, click the checkbox which is located next
to its name and then click _Create_. Note that when you click the checkbox, the
Errata Tool will show all the bugs that will be included in the new advisory.
When you click _Create_, the Errata Tool creates a basic skeleton and includes
all approved bugs in the selected component and release in the bug list.

Much of the information about the advisory is pulled into the text—synopsis,
topic, problem description, solution, and references—automatically based on
available or provided data. However, the initial text is nowhere near complete
at this point. You ought to edit it appropriately and ask Engineering Content
Services to review it: click _Edit details_:

[![step4](images/newerrata/newerratastep4.png)](images/newerrata/newerratastep4.png)

Then make sure the text meets the standards described at [Errata
Howto](https://home.corp.redhat.com/wiki/erratahowto). You can also add any bug
numbers that were not added automatically, but the bugs must be approved (ACKed)
and must be in an eligible state for inclusion in an advisory.

The set of eligible bug states is configurable for each product.  The default
configuration, used by most products, is that only bugs in the MODIFIED or
VERIFIED states can be added to advisories, except for _TestOnly_ bugs, which
must be in the ON_QA or VERIFIED states.

Therefore, if the plan is to fix more bugs than the Errata Tool included
automatically, you need to make the bugs eligible to be added first. The bug
numbers can, however, be supplied anytime later.

Click _Preview_. The Errata Tool will examine the advisory and warn you if it
contains typographical errors. If you are satisfied with the text, click the
_Request docs approval_ checkbox above the form and save the advisory. If not,
go back to the previous form, alter the text and submit it again. If you
clicked the checkbox, the advisory will also be submitted to Engineering
Content Services, which reviews all advisories before they are shipped.

### Clone from existing advisory

This is how the form looks:

[![step5](images/newerrata/newerratastep5.png)](images/newerrata/newerratastep5.png)

Click "Clone an advisory" and supply the appropriate previous advisory name.  If
you do not know an advisory that can be used as a template, you need to find the
advisory in the Errata Tool. To find it, you can use the search form at the very
top of the page and enter the name of the component. The history of its
advisories will be displayed (unless it is the first time the component has been
updated):

[![step5](images/newerrata/newerratastep5.1.png)](images/newerrata/newerratastep5.1.png)

Copy the name (RHXA-YYYY:NNNNN) of the last one. Hint: if you can choose the
name of an advisory affecting the same major release that you are filing an
advisory for, such as RHEL 6, choose it, you will have even less work to do.  Go
back to the advisory creation page and paste the name to the clone field.
Click on the arrow next to the clone field to submit.

Input fields on the _New Advisory_ form will now be filled according to the
cloned advisory.  This form consists of two major parts: _Advisory Summary_ and
_Advisory Content_, both of which contain many fields. They all should be
straightforward, but please make sure the Advisory Summary is set up correctly
and edit the Advisory Content according to
[Errata Howto](https://home.corp.redhat.com/wiki/erratahowto).

**Please pay special attention to the format of the synopsis. The Errata Tool
will try to determine the component name from the synopsis and assign the
advisory to the QE group which owns the component. If the Errata Tool fails to
determine the component, the advisory will be assigned to the meta group
Default and no specific QE group will be notified.**

You must also enter the IDs of the bugs that are to be fixed in the advisory,
but they must be approved (ACKed) and must be in an eligible state in order for the
Errata Tool to accept them.

The set of eligible bug states is configurable for each product.  The default
configuration, used by most products, is that only bugs in the MODIFIED or
VERIFIED states can be added to advisories, except for _TestOnly_ bugs, which
must be in the ON_QA or VERIFIED states.

Therefore, you need to make all the bugs that you
want to add capable of being added. The list of bug numbers can be completed
anytime later, but you must enter at least one usable bug number now.

Click _Preview_. The Errata Tool will examine the advisory and warn you if it
contains typographical errors. If you are satisfied with the text, click the
_Request docs approval_ checkbox above the form and save the advisory. If not,
go back to the previous form, alter the text and submit it again. If you
clicked the checkbox, the advisory will also be submitted to Engineering
Content Services, which reviews all advisories before they are shipped.

### Create manually

This is very similar to the previous option, but the clone feature is not used.
The same form (_New Advisory_) will be displayed. When not using clone, the
advisory will initially contain very little information, so you will have to
enter a lot of text manually. Again, the text must obey the instructions from
[Errata Howto](https://home.corp.redhat.com/wiki/erratahowto) and all bugs that
you enter must be approved (ACKed) and must be in an eligible state.

Add packages
------------

Regardless of the method you use to create the advisory, the next step is
usually to add packages to the advisory. The only exception to this is for
text-only advisories, which are a special case and are used only if the
update provides file types that are not supported by the Errata Tool or the
advisory is only providing advice and is not shipping any files. A checkbox
in the advisory editor allows you to mark an advisory as text-only.

Your packages must be built and tagged correctly in the build system. This
part of the workflow is described in [Brew Howto](https://home.corp.redhat.com/wiki/BrewHOWTO).

Make sure you are looking at the _Summary_ tab in your advisory and click
_Edit builds_:

[![step6](images/newerrata/newerratastep6.png)](images/newerrata/newerratastep6.png)

Alternatively, you can get there by clicking the _Builds_ tab. In either case,
the next page contains one or more text areas, each of them labeled _Brew
Builds for ..._:

[![step7](images/newerrata/newerratastep7.png)](images/newerrata/newerratastep7.png)

Enter the NVR (Name-Version-Release) of the build that you want to add to the
advisory and click _Find New Builds_. If the build is found and is acceptable,
click _Save Builds_. If an error occurs, you are given further instructions;
follow them and return here when the problem has been resolved.

### Review the file list

The whole errata file list is now displayed. You can see which products,
releases, variants and architectures will be affected. Please review the file
list and make sure it is correct. This is how it can look:

[![step7](images/newerrata/newerratastep7.1.png)](images/newerrata/newerratastep7.1.png)

**Warning: If you have created a new subpackage, you need to contact [Release
Engineering](mailto:release-engineering@redhat.com) and ask them to enable the
new subpackage in Product Listings.** When they resolve your ticket, they will
either reload the file list for you, or you will have to reload it yourself.
To do so, click _Reload files for this build_ in the errata file list. The
file list should then be displayed correctly.

If there are RPMs in a build that are not present in Product Listings, Errata Tool
will show them as follows. The warning may be dismissed by a user with `admin`
or `releng` roles.

[![product_listings_mismatch](images/newerrata/product_listings_mismatch.png)](images/newerrata/product_listings_mismatch.png)

Likewise, if you need to replace the currently included build with a new one,
for instance because more bugs have just been approved, you can use the form
again: just replace the current NVR with the new one and submit the form.
Alternatively, you can click _Remove this build from errata_. This link is
also useful if the advisory was originally supposed to contain multiple
components but that is not desired anymore, although such advisories are not
common. This topic is described in the very next section.

### Set dependencies between advisories, if they exist

More than one package (component) can be included in one advisory, but usually
we ship just one component per advisory. An example of an exception is firefox
and xulrunner; they could be shipped in two separate advisories, but since
they are closely related and must be updated together, we always put them into
a single advisory. However, this is really an exception. Unless told
otherwise, add just one component to your advisory.

Dependencies between packages in two advisories are common, however. If your
new package does depend on another one (usually from the same release, e.g
RHEL-6.4.0), you ought to make your advisory depend on the related one. There
are two reasons why you ought to do so:

- Your advisory will not be released before the advisory providing the package
  you depend upon, too.

- You will help Quality Engineering a lot, because their automated tests will
  be able to update all the packages together, which would otherwise fail due
  to unsatisfied dependencies.

To make your advisory depend on another advisory, go back to the _Summary_ tab, click
_More_ in the _Approval Progress_ section, and choose _Edit Dependencies_:

[![step8](images/newerrata/newerratastep8.png)](images/newerrata/newerratastep8.png)

A new form appears. Click _Add_ in the _Depends on_ section:

[![step8](images/newerrata/newerratastep8.1.png)](images/newerrata/newerratastep8.1.png)

An input field will be displayed instead of the button. Enter the ID of the
advisory providing the dependency, and click _OK_. An updated dependency tree
for the advisory will be displayed:

[![step8](images/newerrata/newerratastep8.2.png)](images/newerrata/newerratastep8.2.png)

Notes:

- You can use the search form at the top of the page to find the required
  advisory.

- Only use this feature if the packages in your advisory cannot be updated
  unless the packages from the adjacent advisory are also updated.

- Do not enter the ID of an advisory which has already been shipped live.

Provide instructions for QE on how to test the advisory
-------------------------------------------------------

Click the _Details_ tab, scroll down (or click the headers of the individual
sections to fold them), and click the _Edit Notes_ button:

[![step8](images/newerrata/newerratastep8.5.png)](images/newerrata/newerratastep8.5.png)

A text area will be displayed. Please help QE determine how to test the bug
fixes or enhancements that the new packages bring. Write:

- A brief description of the problem(s) which is/are supposedly fixed here and
  how to reproduce the problem on the old, buggy package.

- A description of how the problem was fixed and how to verify the fix, if not
  already covered above. A snippet of shell code or a small test script is a
  good idea. For security issues any known exploits should be given to QE.

- Any additional special considerations.

[![step8](images/newerrata/newerratastep8.6.png)](images/newerrata/newerratastep8.6.png)

Finally, click _Save Changes_. **Thank you!** (On behalf of QE.)

RPMDiff
-------

When the file list was saved, an [RPMDiff](https://docs.engineering.redhat.com/display/HTD/RPMDiff) run was scheduled
automatically. This tool compares the current version of the package in the
given release to the new one and reports all their differences. It also
performs a few sanity tests on the source RPM and the contents of the binary
(or noarch) packages. Your next task is to wait until RPMDiff is finished and
review the results.

As the advisory submitter, you will get an e-mail when the RPMDiff tests
complete. The e-mail will also contain a link to the overview of the results,
or you can see it if you click the _View_ button in the _RPMDiff Tests_ row in
Advisory Progress:

[![step9](images/newerrata/newerratastep9.png)](images/newerrata/newerratastep9.png)

Alternatively, you can get there by clicking the _RPMDiff_ tab. In any case,
the RPMDiff overview shows basic information about the run and a link to the
individual tests:

[![step9](images/newerrata/newerratastep9.1.png)](images/newerrata/newerratastep9.1.png)

**Warning: The old package NVR is sometimes wrong. If you encounter such an
issue, please file a ticket with
[errata-admin](mailto:errata-admin@redhat.com); the ticket should contain the
ID of the advisory and a brief description of the problem.**

Click the ID of the RPMDiff run or the result. You will get a list of all the
tests that RPMDiff performed. Any tests whose results need to be reviewed are
highlighted:

[![step9](images/newerrata/newerratastep9.2.png)](images/newerrata/newerratastep9.2.png)

You are required to check every test whose result is _Failed_ or _Needs
Inspection_. If the reported problem is expected, you can waive it:

[![step9](images/newerrata/newerratastep9.3.png)](images/newerrata/newerratastep9.3.png)

**Please do not waive problems that do not make sense to you. You must be sure
you understand what RPMDiff is trying to tell you. Also, please provide
meaningful waiver descriptions.**

Some failures can only be waived by the Security Response Team or Release
Engineering. If that happens, just follow the instructions provided by the
Errata Tool.

If a result shows that something is now broken, you need to build a new
package and replace the old one. This is called _respinning_ and is a matter
of opening the _Builds_ tab again and changing the NVR in the text area.
RPMDiff will run again on the new file list.

When you have waived a result that needed inspection or was a failure, the
test will no longer be yellow or red in the overview; it will be green, but
the shade of green will be different than the color of the tests that passed.
This difference allows anyone to see what was waived.

When every test whose result is _Failed_ or _Needs Inspection_ has been waived,
the overall result of the RPMDiff run will be _waived_ too.

Submit the advisory to QE
-------------------------

When all the above-mentioned steps are complete, go back to the _Summary_ tab
and click _Move to QE_:

[![step10](images/newerrata/newerratastep10.png)](images/newerrata/newerratastep10.png)

A dialog will be displayed. Select _QE_ and click _Change_ to change the
advisory status from _NEW_FILES_, which is always the initial state, to _QE_,
which indicates that QE can start working on the advisory. You can also add a
comment describing this action, but it is not mandatory. This is how the
dialog looks:

[![step10](images/newerrata/newerratastep10.1.png)](images/newerrata/newerratastep10.1.png)

That is the end of the advisory filing process, but it does not mean that you
can forget about the advisory. It can be given back to you if more bug fixes
are approved or if QE finds a serious issue.

Editing an advisory
-------------------

Ideally, the packages that you submit to QE are successfully tested, no
additional bug fixes are necessary, and the advisory is eventually shipped
live. Unfortunately, it is not always the case.

If you need to replace the package with a newer release, you must first change
the state back to _NEW_FILES_ (unless QE has already done that) and edit the
advisory. The process of altering the file list was described in the RPMDiff
section above. A new RPMDiff run will be scheduled after you edit the file list,
but this time it will compare the latest build to the previous one, so you
will only need to review the latest changes.

If you altered the file list because you had fixed a bug that was not
originally included in the advisory bug list, you need to alter the bug list
too. Fortunately, the Errata Tool can add the new bug automatically, but it
must be in an eligible state and fully ACKed. Additionally, the advisory must
be filed against a non-ASYNC release (e.g. RHEL-6.4 or FAST5.9) in order for
this feature to work. Regardless of the release type, however, the first step
is to click the _Add bugs_ button in the _Bugs_ section of the advisory
summary:

[![step11](images/newerrata/newerratastep11.png)](images/newerrata/newerratastep11.png)

- If the advisory in question is ASYNC, the normal editor will be displayed. It
  is the same editor that was used when the advisory was being filed
  (manually). Scroll down to the _Bugs or JIRA Issues Fixed_ field, and enter
  the new bug ID(s). Then click _Preview_. If the bug list is acceptable,
  a preview will be displayed; if not, you will be given the reasons why the
  bugs could not be added. Save the advisory.
- If it is a non-ASYNC advisory, the Errata Tool will offer you all the bugs
  that are acceptable. You can select the bugs that you really want to add,
  or you can simply click _All_. Finally, click _Add Bugs_:

[![step11](images/newerrata/newerratastep11.1.png)](images/newerrata/newerratastep11.1.png)

**The note below the form contains a link to a page that should help you if you
expect a bug to be available here but it is not offered.** When you click the
link, the _Bug Advisory Eligibility_ page will be displayed. Click the
_Enter Bug ID_ button, enter the ID of the bug into the input field that pops
up, and click _Submit_. The Errata Tool will explain why the bug cannot be
added by showing the bug meta data and examining the eligibility checklist:

[![step11](images/newerrata/newerratastep11.2.png)](images/newerrata/newerratastep11.2.png)

The page will also allow you to sync the Errata Tool with Bugzilla so that
it can obtain fresh data (in case the cached data is stale).

If a bug cannot be added via this page and all your attempts to make the Errata
Tool consider the bug eligible have failed, try adding it manually using the
second link in the note on the _Add Bugs_ page.

Similarly, if a bug fix had to be reverted, the bug list needs to be updated to
omit the reverted bug ID. To do so, click the _Remove Bugs_ button and use the
next form; it is similar to the form for adding bugs.  Another way, although
not so comfortable, is to use the advisory editor again: just click _Edit
details_ in the _Approval Progress_ section, scroll down to the
_Bugs or JIRA Issues Fixed_ field, and remove the unwanted bug numbers
manually. Click _Preview_ and then save the advisory.

When you are done, please change the state of the advisory back to _QE_ so
that QE can resume their work.

If no other respin is needed, the advisory will go through various states
until it is eventually shipped live. You do not need to take any action unless
you are specifically asked.

Most of the described steps are logged in the Errata Tool as automated
comments, which are also sent to you by e-mail. In addition, you will get
e-mail notifications from other people working on the advisory and certain
tools that are used in the process. Be prepared for them and make sure you do
not miss any important message or request. If you want to set up an e-mail
filter for the Errata Tool, please refer to
[Mail Filtering on the QE Wiki](https://wiki.test.redhat.com/Faq/TipsAndTricks/MailFiltering).
