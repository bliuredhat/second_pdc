### Confirm deletion of CDN repository package tag template

(CDN repo package tag management is part of the work-in-progress support for
pushing docker images and was shipped recently, (see [Bug
1278656](https://bugzilla.redhat.com/1278656)), even though full support
for pushing docker images is not yet complete.)

When deleting a CDN repository package tag template (which are used
for Docker packages), a confirmation prompt is now shown.

[![Remove tag](images/3.12.3/removetag.png)](images/3.12.3/removetag.png)
