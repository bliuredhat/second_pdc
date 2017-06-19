### Fix SQL escaping error

A bug affecting some older versions of MySQL was causing a problem with some
SQL comments containing a single quote. This was causing delayed job
processing to fail in some cases. In Errata Tool 3.10.5, the single quotes
have been removed to work around this issue.
