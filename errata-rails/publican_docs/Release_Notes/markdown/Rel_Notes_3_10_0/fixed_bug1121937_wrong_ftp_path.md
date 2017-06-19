### Fixed wrong FTP path for variants with multiple dashes

A bug was fixed which caused Errata Tool to generate incorrect FTP
paths for files belonging to a few RHEL variants.  This caused some
FTP pushes to fail.

Only variants containing multiple dash characters in their name
were affected by this bug - for example, 6Server-SJIS-6.5.Z.

For more information, please see
[Bug 1121937](https://bugzilla.redhat.com/show_bug.cgi?id=1121937).
