### Prevent post push tasks running twice in some cases

In the case where both CDN and RHN push jobs were finishing at the same time,
in some cases their post-push background jobs would be run more than once,
which caused problems since some post-push tasks must only be run once after
both CDN and RHN pushes have completed.

This is now fixed and the post-push tasks will be run once even if the push
jobs finish at the same time.
