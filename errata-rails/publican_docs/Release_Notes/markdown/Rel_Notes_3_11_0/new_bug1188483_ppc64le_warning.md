### Added ppc64le build awareness for RHEL-7.1

For RHEL-7.1 ppc64le builds have their own separate dist tag in Brew. Hence
RHEL-7.1.Z advisories need to have '.ael7b' builds added in addition to
the regular '.el7' builds.

To assist with this, Errata Tool will automatically check for corresponding
ppc64le builds when a build is added to an RHEL-7.1.Z advisory. It will also
show a notice with links to further information wherever ppc64le builds may be
required.

There is more information about RHEL-7.1 and ppc64le here in [the
FAQ](http://etherpad.corp.redhat.com/rhel7-1-ppc64le-faq).

![Ppc64le Build Detected](images/3.11.0/ppc64le-added.png)

![Ppc64le Build Missing Warning](images/3.11.0/ppc64le-warning.png)

![Ppc64le Build Notice](images/3.11.0/ppc64le-notice.png)

This fix was earlier deployed in the Errata Tool 3.10.6.3 hotfix release so it
was available for RHEL-7.1 GA.
