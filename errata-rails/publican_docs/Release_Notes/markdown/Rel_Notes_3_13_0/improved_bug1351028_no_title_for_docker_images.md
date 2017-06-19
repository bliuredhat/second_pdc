### File title not required for Docker images

Previously, Errata Tool required a file title to be entered for Docker
image files, as this is required for all non-RPM files in an advisory.

This requirement has been removed. Errata Tool will no longer require
a file title for docker images. Other non-RPM files attached to an
advisory will still require file titles.
