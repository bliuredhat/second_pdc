### Fixed released package data for multi-product advisories

Previously, when advisories were shipped to multiple products using
[multi-product channel/repo mappings](https://errata.devel.redhat.com/multi_product_mappings),
Errata Tool failed to track released package data for the mapped
destination channels/repos.

This caused release package data to be incomplete for multi-product
advisories, which could interfere with RPMDiff and TPS tests.

This has been fixed; Errata Tool now considers all multi-product
mappings when storing released package data.
