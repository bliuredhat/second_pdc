### Warning if product version brew tags overridden by release

Errata Tool now shows a warning message in the product version screen if
the brew tags configured for the product version have been overridden for
any releases.

If a release used by an advisory has configured a non-empty list of valid
brew tags, then the tags configured in the product version are ignored.
Previously, there was no warning about this.
