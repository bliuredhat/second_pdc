### Add comments to advisory for batch operations

This change adds comments to advisories when their batch changes.

If an advisory is removed from a batch by the system, an explanatory
comment is also added. This can occur if the batch is being released
but advisories assigned to the batch are in NEW_FILES, QE or REL_PREP
states.
