### Update priority of TPS publication queue higher

After the push of a large number of advisories, such as during the release of
RHEL-7.2, many background jobs are added to the job queue to handle post-push
tasks related to shipping advisories. These jobs can take several hours to be
processed.

The job that updates the TPS queue previously had the same default priority as
these push related jobs and hence it would be delayed significantly when there
were many other jobs in the queue. This caused the TPS queue to not be updated
for long periods of time and scheduled TPS jobs would not appear in the queue
and hence not be started. Also completed TPS jobs would incorrectly remain in
the queue, causing TPS workers to run them again.

This issue has been addressed by increasing the priority of the TPS queue update
job so the TPS queue will be updated frequently even when there are many other
queued jobs.
