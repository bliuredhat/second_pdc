### Fixed "Container" tab sometimes missing data

Occasionally the "Container" tab for Docker advisories would display
"No content advisories found" for one or more image builds that did
have data in MetaXOR/Lightblue.

This only happened for builds with multiple record versions in Lightblue,
and only some of the time (the page would usually display correctly when
refreshed).

This has now been fixed.
