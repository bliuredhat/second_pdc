Release Notes for Version 2.3
=============================

Overview
--------

The 2.3 release focusses on the following main areas:

* A new search mechanism called "Advisory Filters"
* A refactor of advisory Views (State View, Flat View and Control Center are
  now combined into ('Summary' and 'Details').
* A new layout and overall look and feel. (The ESO theme).

It was released on August 21st, 2012.

(Note: Click on the screenshots below to view them at full size,
then click your browser's back button to return).


Filters
-------

### Filter Basics

"Filters" are essentially just searches on advisories.  The filter drop down in
the filter bar shows what filter you are currently looking at.  The advisory
list below the filter bar is the list of advisories produced by the filter.
There is a text description of the currently active filter on the right side of
the the filter bar.

[![009](images/rel23/s009.png)](images/rel23/s009.png)

To change the filter parameters click 'Modify'. The filter parameter form will appear
in a modal dialog. In the filter parameter form you can select different search criteria.
The majority of the drop-down select elements allow selection of multiple values. For
example if you choose more than one product, the filter will show advisories from any of
the selected products. To make it easier to find the item you are looking for,
the drop-down select allows type-ahead searching. The screenshot below shows the user
type 'fast' in the Release select box.

As well as search parameters, there are grouping, sorting and list format options
on the filter form.

Once you have set all the search parameters, click 'Apply' to run the filter.

[![010](images/rel23/s010.png)](images/rel23/s010.png)

The advisory list should now show advisories that match the filter's search criteria.
Notice that the filter bar now says, 'Unsaved Filter'. The text description in the filter
bar should also match the search criteria you set.

Notice you can easily see how many advisories are returned, (in this case 34),
and change the pagination and format settings using the 'Per page' and
'Format' controls on the right.

[![011](images/rel23/s011.png)](images/rel23/s011.png)

### Using 'Group By'

If you choose one of the 'Group By' options on the filter form, the advisory list will
be grouped by that item. In the example here the filter is grouped by advisory 'State'.

[![013](images/rel23/s013.png)](images/rel23/s013.png)

[![014](images/rel23/s014.png)](images/rel23/s014.png)

### Using Formats

The way the advisory lists are rendered is determined by the 'Format' option.
There are currently three formats. The 'Standard' format is the default and is the
one we have been looking at so far. The 'Secalert List' uses a format similar to the
'Advisories' list in the 2.2.x Errata Tool. The 'QA Requests' format is similar to
the old 'QA Requests' list in the 2.2.x Errata Tool. (The 'QA Requests' format may
be retired as it is largely superceded by the 'Standard' format).

The screenshot below shows the same filter with the 'Secalert List' format. Notice the
Group By is still in effect.

[![015](images/rel23/s015.png)](images/rel23/s015.png)

### Saving a Filter

There are a number of different options for grouping advisories. In the example below, the
group by setting is changed to QE Group. Suppose this filter (RHEL advisories for the FAST 6.3
release, grouped by QE group), is something that you want to save for later use.

[![016](images/rel23/s016.png)](images/rel23/s016.png)

If you open the filter form by click 'Modify' or 'New', then click 'Save'
instead of 'Apply' you will be able to enter a name for the filter. Then click
'Save' to finally save the filter.

[![017](images/rel23/s017.png)](images/rel23/s017.png)

Notice that the newly saved filter now appears in the filter drop-down select. You will
now be able to select it again to reuse it.

[![018](images/rel23/s018.png)](images/rel23/s018.png)

### Setting a Default Filter

You can choose which filter you want to be your default filter. Do this via the
Preferences page. You can get to Preferences page via the menu accessible by clicking
your kerberos username in the top bar, or just click the link above the filter bar.

Now this filter will be active when you click 'Advisories' from the main navigation bar, or
when you first visit the Errata Tool site.

[![020](images/rel23/s020.png)](images/rel23/s020.png)

### Updating a Filter

If you need to update an existing filter you can do that by clicking 'Update'. In the example shown
below the user decided to change the filter to show advisories in all states including Dropped and
Shipped. Clicking Update will update the filter.

(You can also a 'Save as...' or 'Delete' a filter using the other form buttons).

[![021](images/rel23/s021.png)](images/rel23/s021.png)

[![022](images/rel23/s022.png)](images/rel23/s022.png)

### Planned Improvements for Filters

Sharing a filter with others can be done now by simply sharing the filter's
url. Filter urls look like this: `https://errata.devel.redhat.com/filter/123`. A
more advanced way to share filters with other users or with all users in your your
role or group may be added in a future release.

Currently not easy to rename a filter, or specify the order that filters appear
in your filter drop-down list. These features may also be added in a future release.


Advisory Views
--------------

In release 2.3 the advisory views known as 'State View', 'Flat View' and
'Control Center' have been combined into two pages (or tabs) called 'Summary'
and 'Details'.

[![034](images/rel23/s034.png)](images/rel23/s034.png)

### Summary View

The Summary page is divided into four sections.
The screenshot below shows the four sections on the Summary page.

(Sections can be collapsed if you don't need to see them by clicking on the
section's title.  In the screenshot all sections are collapsed).

The sections are as follows:

* Approval Progress
* Information
* Bugs
* Comments

[![036](images/rel23/s036.png)](images/rel23/s036.png)

#### 'Approval Progress' Section

This section shows what state the advisory is in and how far through its
approval stages it has progressed. A green check mark indicates a workflow step
has occurred or is passed. An orange pause symbol indicates that the step is
waiting on some action. A red 'no' symbol indicates that the step can't
currently be completed. The right column is intended to show some information
about the workflow step and, where applicable, provide buttons to take actions
related to that step.

The button toolbar on the right can be used to change an advisory's state and
take other actions that are not specific to a particular workflow step.

You can hide completed steps by clicking 'Hide complete'.

The 'Approval Progress' functionality was previously found on the 'Control Center' page.

[![037](images/rel23/s037.png)](images/rel23/s037.png)

#### Changing State

Changing an advisory's state was previously done via the 'State View' page.
Now you click 'Change State' in the 'Approval Progress' button toolbar.

The form shows which state changes are applicable and indicates why
a particular state change is allowed or disallowed. In the screenshot below the
advisory is ready to transition to REL\_PREP.

(Note that users with the Admin or Secalert role are able to override the
normal rules for state transitions).

[![038](images/rel23/s038.png)](images/rel23/s038.png)

After changing the state there is a notification of the change.

[![039](images/rel23/s039.png)](images/rel23/s039.png)

#### 'Information' Section

The information section shows details about the advisory. You can toggle
between a brief view or a more detailed view by clicking 'Show brief details'.

(Note: you can set whether to start with the brief view or not on the Preferences page).

Use the button toolbar to change the QA group or owner, edit the advisory, and
so on. (See screenshot below).

[![041](images/rel23/s041.png)](images/rel23/s041.png)

#### 'Bugs' Section

The bugs section shows the advisory's bugs. You can use the bugs section button
toolbar to reconcile or update bug states.

For advisories with many bugs, the bug list maybe be abbreviated. You can click
to expand it.

(You can configure the bug list to always start expanded on the
Preferences page).

[![042](images/rel23/s042.png)](images/rel23/s042.png)

#### 'Comments' Section

The comments section shows the advisory's comments. The comments are grouped
by what state the advisory was in when the comment was added.

You can now display comments from oldest to newest (like Bugzilla) or
from newest to oldest. Set your default preference on the Preferences page.

[![043](images/rel23/s043.png)](images/rel23/s043.png)

You can collapse or expand comment groups using the links near the button
toolbar, or with the 'Collapse' button on the top right of the comment group.

The default option for expanding or collapsing comments can once again be set
on the Preferences page.

Comment urls should work regardless of the expand or collapse setting. (If a
comment url is present all the comment groups will be expanded automatically to
ensure that the comment link works).

This screenshot shows comments sorting by oldest first.

[![044](images/rel23/s044.png)](images/rel23/s044.png)

Click 'Add Comment' to add a comment. Comments are limited to 4000 characters.

[![045](images/rel23/s045.png)](images/rel23/s045.png)


### 'Details' View

The *Details* page or tab is divided into three sections.

#### 'Details' Section

The first section called 'Details' is identical to the expanded version of the
'Information' section. It shows all the details about the advisory.

[![048](images/rel23/s048.png)](images/rel23/s048.png)

#### 'Content' Section

The *Content* section shows the advisory content such as the topic, problem description and
solution. Most of these fields become part of the public facing content when the advisory is published.

[![049](images/rel23/s049.png)](images/rel23/s049.png)

#### 'Notes' Section

The *Notes* section contains the notes field. Previously this was known as 'How
To Test'. It has been changed to reflect that it can be used more generally to
store any kind of notes as required.

(The example in the screenshot doesn't have any notes entered).

[![050](images/rel23/s050.png)](images/rel23/s050.png)


Layout/Theme
------------

The new look and feel is known as the ESO-Theme. It has been in development for
some time and might look familiar as it is being rolled out across a number of
Engineering Tools.

(Note: There may be some changes to the theme in the near future as a new
*Hosted & Shared Services* branded theme is under development).

### Engineering Tools Menu

This gives you quick access to the suite of Engineering Tools maintained by
*Engineering Services & Operations*.

[![051](images/rel23/s051.png)](images/rel23/s051.png)

### Help Menu

This gives you quick access to help including this documentation. You can also
find links to log a ticket or create a bug.

[![052](images/rel23/s052.png)](images/rel23/s052.png)

### User Menu

If you click your kerberos id you get a menu containing a link to the user Preferences page
and a few other personal items.

[![053](images/rel23/s053.png)](images/rel23/s053.png)


Creating an Advisory
--------------------

### Choosing Creation Method

Creating an advisory has not changed functionally, but the UI has been updated
a little.  "Fast-create advisory for release stream" is what used to be called
the "New improved way".

[![055](images/rel23/s055.png)](images/rel23/s055.png)

Choose a product and a release in the same way as before. The 'Component not
available?' link shows a list of common reasons why a components or bugs
aren't visible on this when you expect that they should be.

[![056](images/rel23/s056.png)](images/rel23/s056.png)


What Else?
----------

There are a number of other bug fixes and improvements. To see what else is
in this release, check the
[bug list in Bugzilla](https://bugzilla.redhat.com/buglist.cgi?product=Errata%20Tool&target_milestone=2.3).
For functionality not mentioned above, there may be some cosmetic improvements,
but no significant functional changes.


What's Next?
------------

The next major release of Errata Tool will be Release 3.0. Its primary focus
is RHEL 7 requirements and an improved and more configurable advisory
workflow mechanism.

Other upcoming functionality for Errata Tool includes the integration of
RPMDiffWeb, ABIdiff, and Covscan (Coverity) into the advisory workflow.
