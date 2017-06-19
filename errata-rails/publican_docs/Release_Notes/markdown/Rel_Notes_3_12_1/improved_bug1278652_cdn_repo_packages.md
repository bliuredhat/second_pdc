### Package mapping for Docker CDN repositories

This change introduces support for mapping packages to CDN repositories,
which will be used to determine the content eligible for push for
certain content types (initially, Docker images).

This is not required for RPM packages, and the release process for RPMs
is not affected by this change.
