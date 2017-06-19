### Support for non-RPM Brew files

Errata for non-RPM products have historically been prepared as text-only
advisories, as Errata Tool has not supported tracking any types of files
other than RPMs.

This release contains the first steps towards support for non-RPM content
in advisories.  This will assist engineers to deliver advisories for non-RPM
products (such as JBoss EAP) and for RPM-based products delivered via
alternative means (such as docker images for RHEL).

When adding brew builds to an advisory, if the build contains any non-RPM
files, the desired types of files for the advisory may be selected interactively:

[![nonrpms1](images/3.10.0/nonrpms1.png)](images/3.10.0/nonrpms1.png)

[![nonrpms2](images/3.10.0/nonrpms2.png)](images/3.10.0/nonrpms2.png)

[![nonrpms3](images/3.10.0/nonrpms3.png)](images/3.10.0/nonrpms3.png)

Non-RPM files in an advisory are then displayed on the advisory file list:

[![nonrpms4](images/3.10.0/nonrpms4.png)](images/3.10.0/nonrpms4.png)

[![nonrpms5](images/3.10.0/nonrpms5.png)](images/3.10.0/nonrpms5.png)

This feature is presented as a technical preview, to be expanded upon in
subsequent releases of Errata Tool.  Non-RPM files are not yet
automatically distributed to RHN or CDN, or included in the published
advisory text.

There is a reminder about this when you push an advisory:

[![nonrpms6](images/3.10.0/nonrpms6.png)](images/3.10.0/nonrpms6.png)

For more information, please see bugs
[660270](https://bugzilla.redhat.com/show_bug.cgi?id=660270) and
[1118516](https://bugzilla.redhat.com/show_bug.cgi?id=1118516).
