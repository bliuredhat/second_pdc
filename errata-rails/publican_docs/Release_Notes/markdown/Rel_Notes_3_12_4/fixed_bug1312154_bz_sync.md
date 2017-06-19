### Fix Errata-Bugzilla sync background job crash

Errata-Bugzilla sync background job used to fail and wouldn't recover
from the failure automatically when it tried to sync bugs that are
inaccessible as it resulted in an XMLRPC::Error.

This has been fixed by passing 'permissive' flag to bugzilla which
returns all accessible bugs and by handling any XMLRPC::Errors while
syncing with bugzilla.
