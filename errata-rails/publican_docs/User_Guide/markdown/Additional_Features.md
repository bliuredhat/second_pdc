Additional Features
===================

This section documents Errata Tool features which are not described
elsewhere in the User Guide.

Pushing Builds to Buildroots
----------------------------

Under typical conditions, the packages for each RHEL release are built
in Brew on top of the latest released packages.  For example, packages
to be released in RHEL 6.6 are built on top of the packages released
in RHEL 6.5.z.

This means if a package in a release influences the build of other
packages in the same release, that influence may be untested until
late in the development cycle, causing bugs to be missed.

For these cases, it's possible to request a build to be immediately
included in the buildroot for a release.  This is useful for ensuring
that updates to system libraries, compilers, or other influential
packages are thoroughly integration tested prior to release.

In order to use Errata Tool to request a push to buildroots, the
relevant build must first be associated with an advisory.  Then, when
viewing the advisory's build list, the "Request Push to Buildroot"
action will be offered:

[![Request Push](images/buildroot-push-1.png)](images/buildroot-push-1.png)

This action may be used at most points in the errata lifecycle.  It
may not be used for dropped or shipped advisories.

After requesting the push to buildroots, RCM tools will pick up the
request and adjust the build's tags appropriately.  Errata Tool
currently is unable to provide feedback for the progress of the
request.

If a build has been requested to push to buildroots, a label is
displayed in the UI:

[![Build with Push Requested](images/buildroot-push-2.png)](images/buildroot-push-2.png)

If you change your mind after requesting a buildroot push, the request
may be cancelled by activating the "Cancel Push to Buildroot" action.
However, if the request has already completed, this action will not
undo the push.  Please contact
[Release Engineering](mailto:release-engineering@redhat.com) if you
need to undo the effect of a buildroot push.
