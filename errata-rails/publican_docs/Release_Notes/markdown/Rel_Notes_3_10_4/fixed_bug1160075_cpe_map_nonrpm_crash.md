### Fixed crash on non-RPM files during CPE map generation

The background process used to generate
[CPE mappings](https://errata.devel.redhat.com/cpe_map_2010.txt) did
not correctly handle advisories containing builds with exclusively
non-RPM files.  CPE map generation would fail when such an advisory
was encountered.

This has been fixed; non-RPM builds are now ignored during CPE map
generation.

<note>

The CPE mapping data contains important information about security fixes that
is consumed by third parties outside of Red Hat. This bug caused that
information to not be updated when new security advisories were shipped. Due
the potentially high impact, this bug was fixed in production prior to the
release of Errata Tool 3.10.4.

</note>
