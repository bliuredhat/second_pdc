### Increased the priority of post-push tasks

Previously, post-push tasks were scheduled with priority level 0, which is the
lowest priority. It shared this priority level with many other background tasks,
including the often hundreds of released package updates. This was causing
delays for secalert and rel-eng.

With this fix, post-push tasks are given a higher priority level than other
background jobs.
