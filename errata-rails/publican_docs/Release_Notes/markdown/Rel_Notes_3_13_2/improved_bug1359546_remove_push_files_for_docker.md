### Removed "Upload errata files" push option for docker push

The CDN push option "Upload errata files" (push\_files) should not be
set for CDN push jobs when pushing a Docker advisory.

Previously this field was shown on the Push screen, but defaulted to
unset. The option is no longer displayed, to avoid confusion.
