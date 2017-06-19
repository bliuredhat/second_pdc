### Improved handling of product versions in XML-RPC API

In order to support a release engineering use-case, important for RHEL 7.1
batched updates, minor improvements have been made to the XML-RPC API.

The `get_advisory_list` method now accepts a list of product version names. When
used, the method will only return errata having builds for the specified product
versions.

The `getErrataBrewBuilds` method now returns the product version associated with
each returned build.

These changes allow errata with multiple product versions (such as ASYNC errata)
to be handled unambiguously, and more efficiently.

(Please note that new users are advised not to make use of the XML-RPC API.  The
[HTTP API](https://errata.devel.redhat.com/developer-guide/api-http-api.html)
is preferred.)
