### Use CDN url in all errata formats

Previously, when a product is configured to only go to CDN not RHN, Errata Tool
generated public errata link to CDN such as

https://access.redhat.com/errata/RHSA-2016:XXXX

Otherwise generated link to RHN such as

https://rhn.redhat.com/errata/RHSA-2016:XXXX.html

This has caused some RHN links to open 404 page.

Eventually Errata Tool has concluded this by adopting the former url to
everywhere, regardless of enabling RHN push or not.
