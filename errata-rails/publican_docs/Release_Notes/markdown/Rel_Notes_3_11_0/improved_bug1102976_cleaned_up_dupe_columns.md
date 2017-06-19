### Cleaned up duplicate columns in database

Certain duplicate columns were removed from Errata Tool's database.
Specifically, the product_version_id column was dropped from the
channels, channel_links and cdn_repo_links tables.

These columns unnecessarily duplicated data from other tables.
Removing them improves maintainibility and prevents bugs where the
duplicated data could become out of sync with the source data.
