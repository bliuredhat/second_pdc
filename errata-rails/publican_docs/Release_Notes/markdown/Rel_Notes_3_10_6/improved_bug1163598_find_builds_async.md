### Improved responsiveness when adding builds to advisory

When adding builds to an advisory, the user experience of the "Find
New Builds" action has been improved.

This action makes various RPC calls to Brew to find and validate the
requested builds. In earlier versions of Errata Tool, these RPC calls
were all performed in the context of a single action after clicking
the "Find New Builds" button.  This process could take several minutes
to complete, during which time Errata Tool wouldn't give any indication
of the progress.

This has been improved by moving the RPC calls into a background job.
The progress of this background job is monitored and displayed in the
UI.

[![Find New Builds - before submit](images/3.10.6/find-new-builds-async-1.png)](images/3.10.6/find-new-builds-async-1.png)

[![Find New Builds - in progress](images/3.10.6/find-new-builds-async-2.png)](images/3.10.6/find-new-builds-async-2.png)

As well as making the UI more responsive, this change makes adding
builds more robust, as the background job is able to retry in the case
of Brew timeouts.
