### Improve the rendering speed for the advisory builds page

A number of performance issues had been fixed in Errata Tool 3.11.3.
This patch fixes additional slow rendering issue for the build page
when an advisory has a large amount of file list.

The performance improvements includes:

* A number of slow database queries have been made more efficient to
  improve their speed.
* Some N+1 database hit scenarios have been identified and fixed.
* Some expensive objects are now cached rather than recalulated more
  than once within single request.
* Reduce unnecessary partial rendering in a page.

Additionally this update adds a 'Push info' link which provides the
information about where the rpms in a particular variant will be pushed,
such as CDN or RHN.

[![Push info](images/3.11.4/push_info.png)](images/3.11.4/push_info.png)
