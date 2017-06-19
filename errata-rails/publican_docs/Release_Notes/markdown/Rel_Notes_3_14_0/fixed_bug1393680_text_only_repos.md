### Only binary CDN repos should receive text-only metadata

Previously, all active CDN repositories were available for selection when
choosing targets for text-only advisory metadata.

Only binary CDN repos should receive metadata, so other repo types (Source,
DebugInfo and Docker) are no longer shown.
