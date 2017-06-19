### Fixed released packages for subpackages moving to/from noarch

Previously, if an advisory included a build with a `noarch` subpackage
previously shipped as non-`noarch` or vice-versa, Errata Tool would incorrectly
omit this subpackage from the list of released packages provided to TPS. This
could cause invalid TPS test runs.

This has been fixed by updating Errata Tool's released package logic to handle
cases where a subpackage is moved to or from `noarch`.
