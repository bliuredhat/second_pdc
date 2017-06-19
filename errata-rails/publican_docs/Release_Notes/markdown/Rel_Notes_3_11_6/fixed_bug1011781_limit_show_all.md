### Fixed filter performance issues

In previous versions of Errata Tool, advisory filters configured using
the "Show all" pagination option could trigger resource exhaustion on
the server, since no limit was internally applied to the number of
advisories rendered in a single request.

This has been fixed by introducing two behavioral changes:

- If the number of results to be rendered on a single page exceeds an
  internally configured threshold, the filter is not run and an error
  is reported.

- It is no longer possible to select the "Show all" option for new
  filters, since the option can't be used safely.

For API users, existing filters using "Show all" will continue to work
(as long as the amount of results don't exceed the threshold).
However, users are encouraged to select a different pagination option
and update their scripts.
