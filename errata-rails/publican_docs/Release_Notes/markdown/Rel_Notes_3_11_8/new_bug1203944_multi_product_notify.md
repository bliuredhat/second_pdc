### Allow subscribing to multi-product mappings

It is now possible for users to subscribe to
[multi-product mappings](https://errata.devel.redhat.com/multi_product_mappings)
in Errata Tool.

Multi-product mappings define the behavior for multi-product advisories,
generally resulting in updates for certain packages being distributed both to
layered and base products in a single advisory.  In earlier versions of Errata
Tool, this feature sometimes resulted in updates being delivered to a layered
product without the knowledge of that product's development and QE teams.

This subscription mechanism will help to avoid such situations by allowing
interested users to be notified whenever a relevant multi-product advisory is
being prepared.
