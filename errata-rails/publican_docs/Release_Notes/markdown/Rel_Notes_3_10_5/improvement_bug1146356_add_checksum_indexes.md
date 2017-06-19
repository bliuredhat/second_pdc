### Improved performance by adding indexes to checksum tables

Indexes have been added to the columns used by Errata Tool to store
the MD5 and SHA1 checksums of Brew files.  This is expected to
significantly reduce the time taken for Errata Tool to add builds with
many RPMs to an advisory.  (Note that this does not reduce the time
spent communicating with Brew, which may also cause slowness sometimes
when adding builds.)
