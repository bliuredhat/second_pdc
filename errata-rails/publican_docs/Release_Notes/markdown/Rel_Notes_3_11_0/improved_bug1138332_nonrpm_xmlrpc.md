### Added non-RPM support to XML-RPC APIs used by Pub

The XML-RPC APIs used by Pub to find the list of files to be pushed to RHN or CDN
have been extended.  Two methods have been added which allow the non-RPM files of
an advisory to be listed, along with their associated metadata.  These APIs
previously were limited to RPMs only.

As a part of this change, support for non-RPM product listings has also been
added to Errata Tool.  However, there's not yet a service in production which
is capable of providing the non-RPM listings.  As a result, Errata Tool 3.11.0
has been shipped with non-RPM product listing support present but disabled.
