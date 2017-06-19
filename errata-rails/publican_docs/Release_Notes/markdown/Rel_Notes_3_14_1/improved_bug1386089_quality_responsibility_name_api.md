### Add quality_responsibility_name to erratum API

The optional parameter `quality_responsibility_name` may be specified to set
 the QE group when creating or updating an advisory via the REST API.

An error will be returned if the name is not a valid QE group name.

A comment will be added to the advisory if the QE group is changed.
