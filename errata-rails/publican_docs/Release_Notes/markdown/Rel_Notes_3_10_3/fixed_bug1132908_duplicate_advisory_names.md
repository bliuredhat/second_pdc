### Fixed duplicate full advisory names

[Bug 856529](https://bugzilla.redhat.com/show_bug.cgi?id=856529) fixed in
Errata Tool 3.6 (November 2013) fixed an issue that meant in some cases two
advisories could be assigned the same "live id".

Even though this prevented duplicate live ids, it was still possible for the
"full advisory name" to contain duplicates since the name was derived from the
deprecated `errata_id` field, which still was susceptible to the original duplicate
problem since it used the SQL `max` function to get the next available id.

Additionally this caused problems when searching for an advisory since the
search query was also using the deprecated field.

This fix removes the deprecated `errata_id` field entirely and uses the
correct live id when deriving the full advisory name.
