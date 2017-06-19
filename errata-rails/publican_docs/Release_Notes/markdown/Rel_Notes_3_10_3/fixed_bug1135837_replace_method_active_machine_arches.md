### Fixed new architectures not being available when creating channels or repos

The method used to determine which architectures are currently active, (and
hence available for use when creating a new channel or CDN repo), was not
working correctly for newly created architectures.

This has been fixed in Errata Tool 3.10.3. Now the new architectures will be
available in the dropdown select when creating an RHN channel or a CDN repo in
Errata Tool.
