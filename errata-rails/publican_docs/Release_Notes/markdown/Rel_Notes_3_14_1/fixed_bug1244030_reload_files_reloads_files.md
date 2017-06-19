### "Reload files" reloads files from Brew, not just listings

The "Reload files" action, which can be invoked from the advisory Builds
screen for advisories in `NEW_FILES`, has been modified. Previously this
action would re-fetch the product listings from Brew, but this has changed
to also import any new files for the build which had not already been
imported into Errata Tool.

Sometimes, files can appear in Brew after the build has been reported as
completed, and this change makes it easier to include these files in an
advisory.
