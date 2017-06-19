### Fixed performance issue in get_advisory_list XML-RPC method

The
[get_advisory_list](https://errata.devel.redhat.com/rdoc/ErrataService.html#method-i-get_advisory_list)
XML-RPC method may be used to query a list of advisories matching
certain criteria.

In previous versions of Errata Tool, this method applied no limit to
the number of advisories returned from a single response; therefore,
queries returning a large number of results could cause performance
issues.

This has been fixed by internally applying a limit on the number of
results able to be returned by this method.

Users of this method who may need to process a large set of results
should use the newly introduced pagination parameters, "page" and
"per_page", documented at the link above.
