### Pre-push content to RHN and CDN

Errata Tool now supports pre-pushing of content to RHN and CDN. This uploads the RPMs
associated with an advisory to RHN or CDN, but does not yet publish the files to
customers.

This improves the performance of the final live push of the advisory, since the
advisory's files are already cached on RHN/CDN.

By default, pre-push of content is automatically triggered after all the RPMs on an
advisory are signed.

The pre-push status for RHN and CDN is summarized on the Approval Progress section when
viewing an advisory, as highlighted below:

[![Approval Progress](images/3.12.2/prepush_status.png)](images/3.12.2/prepush_status.png)

However, pre-push is not mandatory and does not block any state changes for the advisory.

Release engineers may also explicitly trigger pre-push jobs using the
[push API](/developer-guide/api-http-api.html#api-post-apiv1push).
