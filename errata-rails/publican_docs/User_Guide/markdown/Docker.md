Docker Support
==============

Introduction
------------

Errata Tool now includes support for pushing Docker images to CDN.

### Workflow Overview

The Docker push workflow is similar to that used for RPMs. The main
differences are as follows:

- There is currently no automated testing (such as RPMDiff or TPS)
  triggered by Errata Tool for Docker advisories.
- Product Listings are not used for Docker. Instead, packages are mapped to
  CDN docker repositories within Errata Tool.
- Docker images are pushed to separate CDN Docker repositories, but metadata
  will still be pushed to regular (non-Docker) CDN repositories. The selection
  of repositories is performed for each advisory, and is similar to the process
  used for text-only advisories.

### Limitations

- An advisory may contain RPMs or Docker images, but not both.

Initial Configuration
---------------------

These steps would normally be performed by a user with administrative rights.

### CDN Docker Repositories

Docker images are pushed to CDN repositories with the "Docker" content type.
These repositories may be created in Errata Tool in the same way as other
CDN repositories, through the web interface or by using the [API](#docker-api).

[![create_docker_repo](images/docker/create_docker_repo.png)](images/docker/create_docker_repo.png)

### CDN Repository Package Mapping

As Product Listings are not available for Docker images, Errata Tool requires
packages to be mapped to CDN Docker repositories.

Each Docker repository has a _Packages_ tab on its View screen (other repository
types do not include this tab). To create a mapping, enter the package name in
the text field and select _Create_.

By convention, docker packages usually end in `-docker`, for example,
`rhel-server-docker`.

[![repo_package_map](images/docker/repo_package_map.png)](images/docker/repo_package_map.png)

### Configuring Docker Tag Templates

Tag templates are used to determine the tag metadata for Docker images sent to
Pub. Multiple tags may be configured for each package mapping.

A tag template is a string, which may include one or more placeholders that
will be replaced by the relevant values for the Docker image being pushed.

Tag templates may be associated with a particular variant, in which case the
tag will only be applied when that variant is pushed. If no variant is specified,
the tag will apply regardless of variant.

The placeholders supported are `{{release}}` and `{{version}}`. These will be
replaced with the release or version string from the Brew build. Dot-separated
groups of digits may be extracted by specifying the number of groups in
parentheses. For example, if the version string is `v3.2.0.20-3`,
`{{version(3)}}` would return `3.2.0`.

[![tag_templates](images/docker/tag_templates.png)](images/docker/tag_templates.png)

### Setup Push Targets

The Product, Product Versions and Variants needs to have
_Push docker images to CDN_ selected in their Allowed Push Targets, to be
able to push Docker images.

_Push docker images to CDN Docker Stage_ may also be selected (in which case,
_Push to CDN Stage_ should also be selected).

If the push targets are not configured correctly, a message such as
_Cdn Docker is not supported by the packages in this advisory_ will be shown
in the Approval Progress for the advisory.

Advisory Workflow
-----------------

Except where noted below, the workflow for filing an advisory containing
Docker images is the same as the workflow for advisories containing RPMs,
as described in [Filing an Advisory](#filing-an-advisory-filing-an-advisory).

<note>

There is currently no automated testing performed on Docker advisories. Neither
RPMDiff or TPS runs will be triggered.

</note>

### Adding Docker Build and Selecting Docker Image Files

Docker builds should be added to the advisory in the same way as any other
build. When "Find New Builds" is selected, Errata Tool will query Brew for
matching builds.

Errata Tool will detect a Docker build automatically. Docker image files
(which are gzipped tar files) should be indicated with [Docker].
Most builds will also have additional files, such as xml and ks files. These
should not be added to the advisory, and later versions of Errata Tool may
prevent these files from being added.

[![docker_brew_file](images/docker/docker_brew_file.png)](images/docker/docker_brew_file.png)

<note>

An advisory may contain either RPMs or Docker images, but not both.

</note>

### Selecting CDN repos for metadata

Metadata for Docker images should still be pushed to non-Docker repositories.
As with text-only advisories, it is necessary to select the repositories that
should receive this metadata.

[![docker_meta_workflow](images/docker/docker_meta_workflow.png)](images/docker/docker_meta_workflow.png)

### Pushing to CDN

For Docker advisories, it is necessary to push images to CDN Docker and metadata
to the selected CDN repositories. This means both push targets are required, and
a push job will be created for each target.

#### Pushing to Staging

Some product versions and variants may support pushing to CDN Docker staging
(and CDN staging). Note that currently, Errata Tool does not invoke any
automated testing of the staging deployment for Docker images.

#### Push Blockers

There are some Docker-specific conditions that would prevent push from taking place:

- No CDN Docker repository package mappings
- No CDN repositories for metadata
- Content (RPM) advisories that have not yet shipped

If pushing to CDN Docker is blocked, pushing to CDN will also be blocked.

#### Push Options and Tasks

There are no configurable options for pushing to CDN Docker.

For the CDN push, the standard push options and tasks are available.
Note that the _Upload errata files_ option (`push_files`) will not be
shown for Docker advisories.

[![cdn_push_options](images/docker/cdn_push_options.png)](images/docker/cdn_push_options.png)

#### Metadata

When pushing Docker advisories, the CDN Docker metadata will be shown at the
bottom of the screen. This metadata contains details of the repositories and
tags that will be sent to Pub, and should be reviewed before pushing.

### Container Content

Advisories that include Docker images have an additional _Container_ tab. This tab includes
details of content (RPM) advisories for each Docker build, grouped by Docker repository.
The details shown for each content advisory are advisory name, status and synopsis. If the
content advisory has any CVEs, they will also be listed.

[![container_tab](images/docker/container_tab.png)](images/docker/container_tab.png)

The Bugzilla bugs and JIRA issues attached to each content advisory may be viewed, by
using the Show Bugs/Issues button.

All the information shown in this tab is read-only, and is based on data in Lightblue, the
data store used by the Container Catalog.

#### CVEs

CVEs for content advisories will also be shown on the _Details_ tab for the container advisory,
as "Container CVEs". They will also be included in the advisory push metadata and APIs.

#### Comparison With Previous Image Version

Errata Tool can show details of RPM versions within an image that have changed since the previous
version. Click on the 'information' icon as shown below.

[![container_comparison](images/docker/container_comparison.png)](images/docker/container_comparison.png)

API
---

The [Errata Tool Developer Guide](https://errata-devel.app.eng.bos.redhat.com/developer-guide/)
includes details of the HTTP API used to integrate Errata Tool with other systems.

In particular, the
[CDN Repositories](https://errata-devel.app.eng.bos.redhat.com/developer-guide/api-http-api.html#api-cdn-repositories)
section includes APIs for management of CDN Docker repositories,
package mapping and tag templates.

The [Pushing Advisories](https://errata-devel.app.eng.bos.redhat.com/developer-guide/api-http-api.html#api-pushing-advisories)
section describes the API used for pushing advisories.
