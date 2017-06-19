Release Notes for Version 3.7
=============================

Overview
--------

Errata Tool 3.7 is the seventh minor release for Errata Tool 3. The 3.7
release is unusual compared to other releases in that it contains no new
features or bug fixes. Instead, the only changes between Errata Tool 3.6 and
3.7 are related to upgrading the Ruby on Rails web framework from version 3.0
to version 3.2.

<emphasis role="new">new</emphasis>
:   Update Ruby on Rails from 3.0 to 3.2.
    (See [bug 980226](https://bugzilla.redhat.com/show_bug.cgi?id=980226)).

<emphasis role="fixed">fixed</emphasis>
:   Update javascript usage for compatibility with Rails 3.2.
    (See bugs [999648](https://bugzilla.redhat.com/show_bug.cgi?id=999648),
    [1009697](https://bugzilla.redhat.com/show_bug.cgi?id=1009697),
    [1009698](https://bugzilla.redhat.com/show_bug.cgi?id=1009698) &
    [1032879](https://bugzilla.redhat.com/show_bug.cgi?id=1032879)).

<emphasis role="fixed">fixed</emphasis>
:   Update code, plugins and libraries incompatible with Rails 3.2.
    (See bugs [1030177](https://bugzilla.redhat.com/show_bug.cgi?id=1030177),
    [772102](https://bugzilla.redhat.com/show_bug.cgi?id=772102) &
    [1059951](https://bugzilla.redhat.com/show_bug.cgi?id=1059951)).

<emphasis role="developer">developer</emphasis>
:   Create or update packages for all Rails 3.2 dependencies and test in
    rebuilt environment.
    [Bug 1032332](https://bugzilla.redhat.com/show_bug.cgi?id=1032332)

Related Resources
-----------------

* [Release Announcement](https://docs.engineering.redhat.com/display/HTD/2014/02/19/Errata+Tool+3.7+Released)
* [Bug List for Errata Tool Release 3.7](https://bugzilla.redhat.com/buglist.cgi?product=Errata%20Tool&f1=flagtypes.name&o1=substring&v1=errata-3.7%2B)
* [Full code diff](http://git.app.eng.bos.redhat.com/errata-rails.git/diff/?id=3.7-1.0&id2=3.6-0.0)

Benefits
--------

Ruby on Rails 3.0 was released in 2010. Since then numerous improvements and
fixes have been made to the Ruby on Rails web framework. See the release notes
for [Rails 3.1](http://guides.rubyonrails.org/3_1_release_notes.html) and
[Rails 3.2](http://guides.rubyonrails.org/3_2_release_notes.html) for more
details.

In many cases, the latest versions of libraries that Errata Tool uses no
longer support older versions of Rails. Over time this starts to cause
issues associated with running unmaintained versions of libraries and their
dependencies, and using new libraries to provide required functionality and
solve problems becomes difficult.

Additionally, since ruby 1.8 is quite old now and no longer supported
upstream, we need to plan to upgrade to ruby 2.0 in the not too
distant future. Rails 3.x is the last major version of Rails that will support
ruby 1.8. The latest version of Rails (4.0) has dropped support for ruby 1.8.
Many other useful libraries are starting to drop support for ruby 1.8, or will
probably do so in the future. And, since RHEL-7 will ship with the latest ruby
2.0, it won't be possible to deploy Errata Tool on RHEL-7 if it still requires
ruby 1.8.

For the above reasons, it was decided to upgrade Errata Tool to Rails 3.2.

Note that during the Errata Tool 3.7 release cycle, development on release 3.8
has continued in parallel, so many features and bug fixes flagged for Errata
Tool 3.8 are already complete and ready for testing as soon as release 3.7 is
shipped.

During the 3.7 development cycle a signifcant amount of RJS based javascript
needed to be replaced or rewritten to be compatible with Rails 3.2. Also the
last remaining Prototype.js based javascripts were removed and replaced with
jQuery equivalents. The QE team identified and reported many regressions
caused by the javascript changes which were fixed by the development team.

<note>

RJS is a mechanism for doing dynamic page updates using javascript in Rails.
It has been deprecated in Rails for some time, but in Rails 3.2 was removed
entirely.

</note>

Team Changes
------------

The Errata Tool team has recently welcomed Rohan McGovern
(<rmcgover@redhat.com>) and Hao Yu (<hyu@redhat.com>) who are working on
support for adding Jira issues to advisories.

Also Shan Jiang (shajiang) from the Errata Tool QE team has
recently finished up her internship. Thanks Shan for all the great work over
the past six months.

What's Next
-----------

### Errata Tool 3.8

Errata Tool release 3.8 is planned to have a shorter than usual release cycle to
release priority updates and features that have been blocked by the 3.7
release cycle. It will focus particularly on RHEL-7 readiness issues.
The current bug list for Errata Tool 3.8 can be
[viewed here](https://bugzilla.redhat.com/buglist.cgi?product=Errata%20Tool&bug_status=__open__&f1=flagtypes.name&o1=substring&query_format=advanced&v1=errata-3.8).

### Errata Tool 3.9

Planning for Errata Tool 3.9 is underway but will not be finalised until after
3.7 is released. Bugs and RFEs will be chosen from the backlog and from items
that were originally scheduled for previous releases but were pushed back. If
you are interested in being involved in Errata Tool planning please subscribe
to `errata-dev-list@redhat.com`.
