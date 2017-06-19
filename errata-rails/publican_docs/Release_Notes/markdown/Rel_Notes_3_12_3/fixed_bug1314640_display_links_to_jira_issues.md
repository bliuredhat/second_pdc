### Change display links to JIRA issues for CCAT

Previously the CDN Content Availability Testing (CCAT) would raise a ticket in
RT when an advisory's content was unable to be validated. The ticket ID was
passed to Errata Tool via the message bus so failing CCAT jobs could be
displayed with a link to the relevant ticket.

From mid-March, the Release Engineering team moved their ticket queue from RT
to JIRA so now CCAT creates an issue in JIRA instead of a ticket in RT. Hence
Errata Tool has been updated to now support recording the JIRA issue key and
linking to the relevant JIRA issue.

(Note that this was actually released several weeks ago in ET 3.12.2.1).

[![CCAT JIRA link](images/3.12.3/ccatlink.png)](images/3.12.3/ccatlink.png)
