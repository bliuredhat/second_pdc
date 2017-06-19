### CVE list API now returns advisories that are not closed

The https://errata.devel.redhat.com/cve/list?format=json API previously
returned only advisories that had their closed flag set. This meant that
some non-security advisories with CVEs were not being returned, as these
advisories do not always get closed.

This change helps to ensure that the Product Security team have accurate
information, and reduces manual effort.
