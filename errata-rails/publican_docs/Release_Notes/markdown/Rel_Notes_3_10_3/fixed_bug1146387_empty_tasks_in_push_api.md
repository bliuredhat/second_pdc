### Fixed pushing by API with empty pre/post tasks

In the HTTP API for pushing advisories, attempting to specify an empty
list of pre- or post-push tasks was not handled correctly.  Instead of
disabling all tasks, the default set of tasks would be enabled.

This indirectly blocked the usage of this API to perform shadow pushes.

This has been fixed; passing an empty list of tasks now causes all
tasks to be disabled, as expected.
