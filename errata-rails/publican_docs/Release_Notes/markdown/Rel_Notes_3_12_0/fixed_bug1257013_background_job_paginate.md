### Fixed unpaginated background job page

In previous versions of Errata Tool, the
[Background Job Queue](https://errata.devel.redhat.com/background_job) page
would always display the entire background job queue, without limits or
pagination.

This could result in a slow response and high memory usage when accessing the
page.

This has been fixed by updating the page to paginate through 100 jobs at a time.

[![Paginated Job Queue](images/3.12.0/jobqueue.png)](images/3.12.0/jobqueue.png)
