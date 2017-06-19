### Fixed advisory stuck IN_PUSH when CDN push is not applicable

For advisories which support both RHN and CDN pushes, Errata Tool
doesn't mark the advisory as shipped until both push types have
completed.

In earlier versions of Errata Tool, an error in this logic meant that
an advisory whose product version enables both RHN and CDN pushes, but
did not have any CDN repos configured, would never be marked as
shipped.

For such an advisory, after an RHN push completed, the system would
incorrectly wait for a CDN push to complete before performing
post-push tasks.  Since a CDN push cannot be done without configured
CDN repos, this would never happen, and the advisory would effectively
be stuck in the IN_PUSH state.

This has been fixed so that CDN pushes being enabled but inapplicable
no longer interferes with the post-push tasks of an RHN push.
