### Show container metadata for Docker image advisories

The Red Hat Container Catalog (RHCC), where customers can find information
about Docker images shipped by Red Hat, will soon show which RPM-based
advisories are effectively included in a Docker image update, and which bugs
and CVEs were fixed. This information is calculated by a system called
_MetaXOR_, and is derived from a number of different sources, including Brew,
Pulp, and Errata Tool itself.

In this release of Errata Tool the container metadata for a Docker image
advisory can be viewed in Errata Tool. The information is available in the new
_Container_ tab, which shows the constituent RPM-based advisories, along with
their CVEs, bugs and JIRA issues.

[![container_tab](images/3.13.4/container_tab.png)](images/3.13.4/container_tab.png)

Having this information visible while the advisory is being prepared will
allow it to be verified and confirmed to be correct prior to shipping the
Docker image advisory.

For more details on the new Errata Tool functionality related to MetaXOR and
container metadata, see the
[Errata Tool User Guide](/user-guide/docker-docker-support.html#docker-container-content).
