### Released package additions for AUS/EUS not added to mainline

This change fixes a bug which caused errors when trying to add released
packages to AUS/EUS product versions. The Errata Tool incorrectly tried
to add these packages to the mainline product version as well, causing
errors if the version in mainline was newer than the version being added.

Adding released packages to regular Z-stream product versions is not
affected by this change, and these will still be added to mainline
product versions.
