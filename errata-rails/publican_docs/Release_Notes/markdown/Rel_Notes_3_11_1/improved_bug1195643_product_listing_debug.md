### Improved UI for debugging product listing issues

The
[product listing query UI](https://errata.devel.redhat.com/release_engineering/product_listings)
in Errata Tool has been extended to add new debugging features.

It is now possible to see exactly which calls Errata Tool will make to
Brew, and some information about the expected data:

![Product Listings debug info](images/3.11.1/pl_debug_split.png)

Also, when fetching product listings, the raw data returned by each
Brew call will be displayed:

![Product Listings fetch info](images/3.11.1/pl_debug_fetched.png)

These features have been added to assist the diagnosis of product
listings / composedb setup issues, which have regularly caused
problems when new variants are created.

The new features also support debugging of non-RPM product listings
fetched from manifest API, but this is not currently enabled in
production.
