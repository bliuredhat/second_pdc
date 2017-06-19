### Added flag to request push to buildroots

It's now possible to request builds to be pushed into Brew buildroots
via Errata Tool.  This feature facilitates
[a new buildroot testing process](https://wiki.test.redhat.com/BaseOs/Tools/knowledgeBase/glibcstuff#glibcbuildrootready)
intended for use with core system packages such as glibc and gcc.

Requesting a push to buildroots may be done from the advisory builds
page at any time prior to shipping.

[![Step 1](images/3.10.5/buildroot-push-1.png)](images/3.10.5/buildroot-push-1.png)

[![Step 2](images/3.10.5/buildroot-push-2.png)](images/3.10.5/buildroot-push-2.png)

Documentation on this new functionality is available [here in the User
Guide](https://errata.devel.redhat.com/user-guide/additional-features-additional-features.html#additional-features-pushing-builds-to-buildroots).

Errata Tool's API has been
[updated](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html#method-i-buildflags)
to allow querying and setting the buildroot-push flag on builds.
The XML-RPC API has also received a minor update for querying the flag.

Please note that RCM's scripts to monitor and react to this flag had
not yet been deployed at time of writing.
