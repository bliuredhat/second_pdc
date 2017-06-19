### Fixed pushes to CDN stage when CDN live is not enabled

In previous versions of Errata Tool, if a product or product version enabled CDN stage
pushes and not CDN live pushes, CDN stage pushes could be triggered but could not succeed
in Pub. This occurred because Errata Tool failed to provide CDN metadata to Pub unless
CDN live pushes were enabled.

This has been fixed so that errata supporting only CDN stage and not CDN live will be
able to successfully push to CDN stage.
