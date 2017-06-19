### Add content types support in APIs and filtering

Errata Tool now makes it easier to determine the content types of files
that are attached to an advisory.

This support is required to enable the Customer Portal to provide more
specific details of how to install content of different types, in particular
Docker images.

The content_types will be returned as an array of strings, through various
Errata Tool APIs. An advisory may have no content types if no files are
attached (for example, a text-only advisory, or some advisories in `NEW_FILES`
state).

The Advisory Filters now also support content types.

The following content type values are currently supported:

> - `rpm` RPM
> - `docker` Docker image
> - `cab` Windows cabinet file
> - `iso` CD/DVD Image
> - `jar` Jar file
> - `js` Javascript file
> - `ks` Kickstart file
> - `liveimg-squashfs` liveimg compatible squashfs image
> - `msi` Windows Installer package
> - `ova` Open Virtualization Archive
> - `pom` Maven Project Object Management file
> - `qcow2` QCOW2 image
> - `tar` Tar file
> - `txt` Text file
> - `xml` XML file
> - `zip` Zip file
