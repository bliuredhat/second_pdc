### Batch locking

Previously, there was no good way in Errata Tool to indicate that a batch's
content was finalised and no more advisories should be added to it.

In some cases users were attempting to handle this by setting the batch to
inactive, but this also disabled the batch checks and prevented the advisories
from using the correct batch release date.

So to support this use case Errata Tool 3.12.3 release introduces 'batch
locking'. A batch that is locked cannot be assigned any further advisories,
but the batch's 'active' state is unaffected. Any advisories assigned to the
batch will use the batch release date, and the batch-related checks will still
be performed when moving advisories to PUSH_READY.

[![Batch locking 1](images/3.12.3/batchlock1.png)](images/3.12.3/batchlock1.png)

[![Batch locking 2](images/3.12.3/batchlock2.png)](images/3.12.3/batchlock2.png)
