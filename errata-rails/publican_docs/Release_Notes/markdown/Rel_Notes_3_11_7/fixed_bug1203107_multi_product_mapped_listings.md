### Fixed wrong arches and subpackages shipped by multi-product errata

Previously, when using a multi-product advisory, Errata Tool did not
consider product listings when determining which files should be
delivered to each channel/repo on mapped products.

This meant that subpackages and architectures omitted from composedb
for a layered product could still be pushed by Errata Tool, which is
wrong.

This has been fixed by ensuring that Errata Tool fetches and considers
product listings for all of the products used by a multi-product
advisory when determining what should be shipped.
