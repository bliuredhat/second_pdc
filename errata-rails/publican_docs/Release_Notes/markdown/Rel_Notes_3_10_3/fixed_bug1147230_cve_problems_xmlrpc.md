### Fixed ability to add invalid CVE bugs via XML-RPC

A missing validation in
[the XML-RPC API](https://errata.devel.redhat.com/rdoc/SecureService.html#method-i-add_bugs_to_errata)
for adding bugs to an advisory meant that non-secalert users were
incorrectly permitted to add CVE bugs which don't match the advisory's
CVE list.  Errata Tool's UI and other APIs don't permit this.

This has been fixed; the same restrictions now apply whether bugs are
added via the XML-RPC API, the HTTP API, or the web UI.
