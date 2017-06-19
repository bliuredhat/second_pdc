### Fixed wrong packagename in get_advisory_cdn_metadata

In previous versions of Errata Tool, the get_advisory_cdn_metadata
XML-RPC method returned a package "name" property with a value equal
to the name of an RPM's source/main package.

This has been fixed to instead return the name of the RPM subpackage
where appropriate, as expected by Pulp.
