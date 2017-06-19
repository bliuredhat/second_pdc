### Do not offer docker repos for docker advisory metadata

Previously, all active CDN repositories were available for selection in
the "CDN Repos for Docker Metadata" screen.

As docker repos cannot accept erratum metadata, they should not be made
available for selection. As only binary repos are required for metadata,
Errata Tool now shows only those for selection.
