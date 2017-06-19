### cached_listings aware of mapped product versions

Previously, product listings were stored in a cache to improve the performance
against the repeated fetches but these listings didn't contain the listings for
the mapped product versions. Thus, if there were mapped product versions, then
it would always call direct connections to the database.

Now, those listings are also included in the cached_listings.
