### Fixed incomplete split product listings on brew timeouts

Since version 3.11.5, Errata Tool allows builds to be added to an advisory (with
warnings) when product listings are not available.

However, in the case of split product listings, as used by RHEL-6, this change
had an unintentional side-effect.  In this case, Errata Tool needs to perform
multiple calls to Brew to fetch product listings of a single build.  If some of
the calls succeeded while others did not (for example, due to temporary
communication problems with Brew), Errata Tool would incorrectly cache partial
product listings data.

This has been fixed.  In the case of split product listings, Errata Tool now
ensures that product listings data is only saved if it is complete.
