### Check docker builds mapped to repositories on QE transition

Errata Tool now checks that all docker builds in an advisory are mapped
to docker CDN repositories when transitioning from NEW_FILES to QE. This
will help prevent failed staging pushes for docker advisories.

The failure message for unmapped docker builds now references the build NVR
instead of the filename of the image, as the former is more widely used.
