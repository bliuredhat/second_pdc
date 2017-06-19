Advisory Batching
=================

Introduction
------------

Errata Tool supports the grouping of advisories into batches, to facilitate the
co-ordinated release of related or interdependent advisories. A batch contains multiple
advisories, all of which must be for the same release.

Batches are not intended for use with Red Hat Security Advisories (RHSA).

Batch Creation and Management
-----------------------------

### Batch Administrators

Only users with the `admin`, `pm`, `releng` or `secalert` roles may manage
batches, including changing the batch assignment and batch blocker status of an
advisory.

### Enabling Batching for a Release

Batching support needs to be enabled for a release, through the Release Groups
administration page. To enable batching, edit the release and activate the
`Enable Batching` checkbox. This will allow batches to be created for the
release, and also activates automatic batching for new advisories created for
the release.

[![enable_batching](images/batching/enable_batching.png)](images/batching/enable_batching.png)

### Creating and Editing Batches

Batches may be managed from the Advisory Batching administration page. This can
be found by following the `Advisory Batching` link on the Administation screen.

[![batch_admin](images/batching/batch_admin.png)](images/batching/batch_admin.png)

To create a new batch, click the `New Batch` button.

[![new_batch](images/batching/new_batch.png)](images/batching/new_batch.png)

The editable properties of a batch are:

- Name (must be unique)
- Release (only releases with batching enabled will be available)
- Description
- Release date (planned date of release; may be initially empty)
- Active flag (if this is unset, the batch will be ignored by the Errata Tool)
- Locked flag (if this is set, no further advisories may be assigned to the batch)

The same page is used to edit batch details. The Release may only be changed if
the batch contains no advisories.

Batching Advisories
-------------------

### Automatic Batch Assignment

New non-RHSA advisories will automatically be assigned to the next available
batch for that release, if the release for that advisory has batching enabled.
The next available batch is the active, unlocked batch with the earliest release
date that has not started the release process (has no advisories in `IN_PUSH` or
`SHIPPED_LIVE`).

If there is no batch available for the release, a new one will be created.

### Changing Batch Details for an Advisory

The batch assignment and batch blocker status for an advisory may be edited by
selecting `Edit Batch` from the Actions selector. This option is also available
from the `More` dropdown in the Details section of the Advisory Details tab.

[![advisory_edit_batch](images/batching/advisory_edit_batch.png)](images/batching/advisory_edit_batch.png)

### Finding Advisories in a Batch

Batch details for an advisory are shown on the main Advisories list. The list
may be filtered by batch, using the standard filtering dialog.

### Viewing Batch Details for an Advisory

The batch details for advisories are shown in the main Advisories list, and
can also be found on the Advisory Details page.

### Batch Blockers

An advisory may be marked as a batch blocker. A batch may have multiple
blocking advisories. Non-blocking advisories in the batch cannot move to
`PUSH_READY` state until all the blocking advisories in the same batch are in
`PUSH_READY`.

Batch Release Process
---------------------

<note>

Currently, all advisories in a batch still have to be pushed individually (this
will probably change in the future).

</note>

The release process for a batch is considered to have begun when the first
advisory in the batch is pushed. At this point, any advisories in the batch
that are in `NEW_FILES` or `QE` states will be removed from the batch, and
assigned to the next available batch for the release. This means that all
advisories that are intended to be released together as a batch should be
in `REL_PREP` or `PUSH_READY` state before any of them are pushed.

Advisories assigned to a batch will be prevented from moving from `REL_PREP`
to `PUSH_READY` if

- the batch release date is not set, or is in the future,
- (for non-blocking advisories) there are any batch blockers not yet in `PUSH_READY`

A batch is considered to have been released once all its advisories are
`SHIPPED_LIVE`.

API
---

Batches may be managed using the Errata Tool [HTTP API](https://errata.devel.redhat.com/developer-guide/api-http-api.html).
