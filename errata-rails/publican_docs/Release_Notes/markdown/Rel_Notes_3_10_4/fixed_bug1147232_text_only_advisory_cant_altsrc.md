### Fixed 'Altsrc' push target being available incorrectly

Altsrc is the push target for the CentOS git repositories. For advisories
without any content to push to CentOS Errata Tool was incorrectly showing the
Altsrc push as a workflow step, and also it was providing Altsrc as an option
when pushing the advisory.

This has been fixed in Errata Tool 3.10.4. Now advisories without content for
git.centos.org will correctly reflect this on the sumary page, and the push
option will not be selectable if there is no applicable content.
