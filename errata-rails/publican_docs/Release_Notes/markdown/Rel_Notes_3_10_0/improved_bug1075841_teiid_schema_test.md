### Add mechanism to test all Teiid DDLs against our schema

Each different Teiid VDB provides access to Errata Tool data by defining a
number of views. The SQL to create those views can be found in DDL files in the
[hss_teiid repo](https://code.engineering.redhat.com/gerrit/gitweb?p=hss_teiid.git).

In order to find out in advance if any changes to the Errata Tool schema might
break those views and hence break the applicable Teiid VDB, there is now a way
for developers to easily test all the DDL files on the schema before it ships
live.

This is a first step towards a broader review of the existing Teiid views for
Errata Tool, (see
[Bug 1125124](https://bugzilla.redhat.com/show_bug.cgi?id=1125124)), and towards
providing better support and documentation for users who want to use Teiid to
access Errata Tool data.

For more details please see
[Bug 1075841](https://bugzilla.redhat.com/show_bug.cgi?id=1075841).
