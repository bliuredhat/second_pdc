### Refresh cached product listings when they are empty

If Errata Tool already has a cached product listing it will use that when
adding a build to an advisory. This helps add the build more quickly since
fetching the listings from brew can sometimes be slow.

However in the case where Errata Tool had cached an empty product listing, it
would incorrectly continue to use that empty listing and the build would not
be able to be added. This was causing a number of support requests to clear
the empty product listing cache manually.

This is fixed in Errata Tool 3.11.3. When adding builds, cached product
listings that are empty will not be considered valid and the listings will be
reloaded from brew.
