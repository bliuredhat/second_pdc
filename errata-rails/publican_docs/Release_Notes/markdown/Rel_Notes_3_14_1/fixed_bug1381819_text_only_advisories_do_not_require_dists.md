### Add a flag to indicate if text-only advisories require dists

Previously there was a request to disallow pushes for text-only advisories
without channels or repos to avoid certain cases where the advisory
information would not be properly pushed. See [Bug
1349662](https://bugzilla.redhat.com/1349662) for more details.

However this caused problems for some Middleware products that do not need any
channels nor repos for text-only advisories. They are not required to be
present on RHN nor RHSM.

This patch provides a configuration option for each product called 'Text-only
advisories require dists?' which will indicate whether the product allows
pushing text-only advisories with any channels or repos.

The default for this configuration option is true, but the following products
will have this set initially to false.

- Red Hat JBoss A-MQ
- Red Hat JBoss API Management Gateway
- Red Hat JBoss BPM Suite
- Red Hat JBoss BRMS
- Red Hat JBoss Core Services
- Red Hat JBoss Data Grid
- Red Hat JBoss Data Virtualization
- Red Hat JBoss Enterprise Application Platform
- Red Hat JBoss Fuse
- Red Hat JBoss Fuse Service Works
- Red Hat JBoss Operations Network
- Red Hat JBoss Portal
- Red Hat JBoss SOA Platform
