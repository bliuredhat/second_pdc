### Filter group order respects sort order

Previously, if "Group By" was used in an Advisory Filter, the groups
would always be sorted in ascending order, even if this contradicted
the ordering specified in the "Sort by" field.

This has been fixed. If the selected group and sort by options are for
the same field, the requested ordering direction will be used.
