### Removed size limit on bugs fixed field

The bug/issue ids fixed form input field was unnecessarily being limited to
8000 characters. Some advisories with a large number of bugs were exceeding
this limit. The input field was being truncated before the form was submitted
causing problems updating advisories' bug lists.

This has been fixed; the input field limit has been removed so advisories
with large numbers of bugs are handled correctly.
