### Fixed FTP push of non-RHN advisories

In earlier versions of Errata Tool, a faulty check prevented FTP
pushes for any advisory not using RHN.  FTP pushes would be
incorrectly blocked with the message, "This errata cannot be pushed to
RHN Live, thus may not be pushed to FTP".

This interfered with the publishing of source RPMs for products only
distributed via CDN, such as Red Hat Satellite 6.

This has been fixed in the current version of Errata Tool.  FTP pushes
are now permitted whenever:

* RHN pushes are permitted, for an RHN-only advisory
* CDN pushes are permitted, for a CDN-only advisory
* RHN and CDN pushes are both permitted, for an RHN and CDN advisory
