### Removed misleading message for advisory with no builds moving to QE

As part of the recently added support for naming non-RPM files, there is a
requirement that all non-RPM files added to an advisory have been given a name
before the advisory can progress to QE.

When an advisory did not yet have builds added the status text for that
requirement was "No non-RPM files in advisory", which, while technically
correct, was not very useful given there are no files at all.

In Errata Tool 3.10.4 this message is omitted for advisories without builds.
