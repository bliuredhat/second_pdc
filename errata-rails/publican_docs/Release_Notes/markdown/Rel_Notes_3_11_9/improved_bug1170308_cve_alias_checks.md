### Ensure CVEs have associated CVE bugs

Additional checks have been added to ensure that CVEs added to the
advisory CVE list match CVE bugs associated with the advisory.

The new checks confirm that each CVE has a matching bug with the
same CVE name as one of its aliases, and that new CVE bugs (with
CVE aliases) have a matching entry in the advisory CVE list. This
is in addition to the existing CVE checks (which look for the CVE
name in the bug summary).

Any problems are presented as warnings, and do not prevent the user
from saving the advisory.
