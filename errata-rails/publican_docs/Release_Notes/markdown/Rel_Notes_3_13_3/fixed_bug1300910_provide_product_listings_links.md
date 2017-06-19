### For each Brew build, provide links to product listings with cache freshness date

For each Brew build in an advisory, a link to the matching Product
Listings now appears, accompanied by the time at which the information
was fetched from Brew.

[![Sample brew listing](images/3.13.3/provide_product_listings_links.png)](images/3.13.3/provide_product_listings_links.png)

Previously it was difficult to determine the cause if incorrect RPMs
appeared in the list due to stale cached information from Brew; this
change makes it easier to detect and correct the issue.
