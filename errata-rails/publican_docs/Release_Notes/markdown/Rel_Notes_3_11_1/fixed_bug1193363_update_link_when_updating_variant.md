### Fixed stale links when moving channel/repo between variants

RHN channels and CDN repos in Errata Tool are linked to variants,
which is used in determining to which channels content is shipped.

Normally, a channel should be linked to the variant which owns the
channel.  This link is created automatically when a channel is
created.

However, in earlier versions of Errata Tool, the link was not updated
when a channel was moved between variants.  This meant that the
channel would remain linked to its original variant, which usually
doesn't make sense.  As a result, content could be shipped to wrong
channels.

The problem was exacerbated by the unclear UI regarding channel links
in Errata Tool.

This has been fixed.  Moving an RHN channel or CDN repo from one
variant to another now also updates the associated channel/repo link.
