### Show build mapping counts in advisory summary

Previously, Errata Tool showed the number of errata build mappings in the
advisory summary screeen, instead of the actual number of Brew builds
attached to the advisory. In many cases, this number is the same, but it
can be different when a build is added for multiple product versions or
multiple file types are added from the build.

Errata Tool now shows the actual number of Brew builds, and (if different)
the number of build mappings.
