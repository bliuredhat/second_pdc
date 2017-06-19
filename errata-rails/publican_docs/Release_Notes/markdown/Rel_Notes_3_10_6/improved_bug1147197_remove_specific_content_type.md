### Support reselecting files of mixed content builds

This is an improvement to the non-RPM files support added recently to Errata
Tool.

Previously, if a build containing multiple file types was added to an
advisory, the only way to change the selected file types was to remove and
then re-add the build.

This has been improved by adding a new UI to allow reselection of desired
file types for a build without first removing the build. This may be done
whenever the advisory is in NEW_FILES state.
