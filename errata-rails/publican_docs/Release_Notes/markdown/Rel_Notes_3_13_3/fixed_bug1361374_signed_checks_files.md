### Advisory considered signed only if all RPMs are signed

When considering if an advisory is signed, Errata Tool now checks that
each file has been signed, instead of relying on the status of the
build. There had previously been push failures caused by mismatches
of signed status between builds and files that had been imported into
Errata Tool.
