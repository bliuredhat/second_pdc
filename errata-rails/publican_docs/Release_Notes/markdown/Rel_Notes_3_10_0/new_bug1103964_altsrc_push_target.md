### Added Altsrc push target for pushing to CentOS git

For RHEL 7 (and certain RHEL 6 packages), source RPMs are unpacked
and pushed to [CentOS git](https://git.centos.org).  This is
sometimes referred to as "altsrc".

Errata Tool previously has not directly supported this method of
pushing sources.  Instead, pub would divert FTP pushes if it
detected SRPMs which should be pushed to git.

This version of Errata Tool now explicitly supports triggering
altsrc pushes in pub.  This allows altsrc pushes to be managed
consistently with other types of pushes and will allow the
diversion code to be removed from pub, making the code easier
to maintain.

[![altsrc1](images/3.10.0/altsrc1.png)](images/3.10.0/altsrc1.png)

[![altsrc2](images/3.10.0/altsrc2.png)](images/3.10.0/altsrc2.png)

For more information, please see
[Bug 1103964](https://bugzilla.redhat.com/show_bug.cgi?id=1103964).
