### Performance improvements

The clearest and loudest message to come from the recent
[Errata Tool User Survey](https://hurl.corp.redhat.com/et-survey) was
that Errata Tool is too slow, and that the poor performance of Errata Tool has
a significant impact on a lot of users.

To address this a number of performance improvements are included in Errata
Tool 3.11.3, including the following:

* A number of slow database queries have been made more efficient
  to improve their speed.
* Some N+1 database hit scenarios have been identified and fixed.
* Some expensive objects are now cached rather than recalulated more than once
  within single request.
* Rails fragment caching is now used to cache advisory comments between
  requests so they render much faster.
* To reduce the wait time before the advisory summary page is responsive,
  some slow to render elements are now loaded asyncronously after the initial
  page is rendered.

The rendering speed was most problematic for advisories with very large file lists.
Testing indicates these improvement reduce the rendering time
significantly for that type of advisory. See
[here](https://bugzilla.redhat.com/show_bug.cgi?id=1172898#c13) for some
example speed comparisons.

For more details please see [bugs 1220614, 1210229, 1207931 and
1121465](https://bugzilla.redhat.com/buglist.cgi?quicksearch=1220614%2C1210229%2C1207931%2C1121465).

Further performance fixes will be included in upcoming Errata Tool
releases.
