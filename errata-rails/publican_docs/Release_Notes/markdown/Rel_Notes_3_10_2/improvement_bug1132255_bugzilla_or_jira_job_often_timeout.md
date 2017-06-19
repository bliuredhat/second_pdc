### Improved synchronization with Bugzilla and JIRA

Bugzilla/JIRA synchronization often times out when the number of bugs/issues
to be updated is very large. Instead of just increasing the timeout of the
delayed job, several improvements have been made to enhance the process.

When Errata Tool has not synchronized with Bugzilla or JIRA for a long period
of time, the number of bugs/issues that are outdated can be massive. This might
prevent the job from finishing before the delayed job timeout, which is five
minutes.

A new methodology has been introduced to make the synchronization process able
to resume from a checkpoint after it fails, effectively continuing from where
it left off, rather than trying failed jobs again from the beginning.

Processing updates for bugs/issues is now split into batches containing
bugs/issues that were updated within a certain configurable period of time
(currently set to six hours). When each batch is completed successfully a
checkpoint is set. This makes it easier for Errata Tool to recover from
an interruption to the syncing process, such as a Bugzilla outage.

There are two jobs that handle Bugzilla/JIRA synchronization. The first job
will mark a configurable maximum number of bugs/issues as dirty. If there are
more outdated or new bugs/issues to mark as dirty, then it will stop and rerun
after a minute to prevent timeout error. The dirty bugs/issues will then
trigger the second job to perform the synchronization.

The second job will synchronize a configurable maximum number of bugs/issues,
(currently set to 1000). If there are more to synchronize, then it will stop
and rerun after a minute to prevent timeout errors.

Lastly, there is also a fix for a bug where the background job 'attempts'
field was not being reset to zero when jobs completed successfully. This was
causing failed jobs to incorrectly behave as though they had failed many
times. The failed attempts counter affects how long the wait is before failed
jobs are retried, so this bug was also contributing to how effectively Errata
Tool could recover from an interruption to the regular syncing process.

For more details see
[Bug 1132255](https://bugzilla.redhat.com/show_bug.cgi?id=1132255) and
[Bug 1126240](https://bugzilla.redhat.com/show_bug.cgi?id=1126240).
