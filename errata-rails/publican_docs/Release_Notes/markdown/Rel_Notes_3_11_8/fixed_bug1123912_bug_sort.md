### Fix incorrect bug priority sorting

When viewing an advisory's bug list you can sort bugs by different attributes
by clicking the applicable column heading.

Sorting this bug list by priority was incorrectly using alphabetical sort
based on the priority name, rather than sorting by the priority level. This
has been fixed in this release of Errata Tool.

Also, 'unspecified' priority is now considered to be above 'low' priority when
sorting the bug list.
