### Improved email headers for certain email notifications

Errata Tool sends out email notifications as a result of certain
events in the advisory workflow.

The headers in some of these emails have been updated to better
reflect the content, and to make it easier to filter the messages.

Advisory live ID change:

- `X-ErrataTool-Component = 'ERRATA'`
- `X-ErrataTool-Action    = 'LIVE-ID-CHANGE'`

Bug added to advisory:

- `X-ErrataTool-Component = 'BUGZILLA'`
- `X-ErrataTool-Action    = 'ADDED'`

Bug removed from advisory:

- `X-ErrataTool-Component = 'BUGZILLA'`
- `X-ErrataTool-Action    = 'REMOVED'`

CVE changed:

- `X-ErrataTool-Component = 'ERRATA'`
- `X-ErrataTool-Action    = 'CVE-CHANGE'`

JIRA issue added to advisory:

- `X-ErrataTool-Component = 'JIRA'`
- `X-ErrataTool-Action    = 'ADDED'`

JIRA issue removed from advisory:

- `X-ErrataTool-Component = 'JIRA'`
- `X-ErrataTool-Action    = 'REMOVED'`

Advisory state changed:

- `X-ErrataTool-Component = 'ERRATA'`
- `X-ErrataTool-Action    = 'STATE-CHANGE'`
- `X-ErrataTool-Previous-Value = (previous state)`
- `X-ErrataTool-New-Value      = (new state)`
