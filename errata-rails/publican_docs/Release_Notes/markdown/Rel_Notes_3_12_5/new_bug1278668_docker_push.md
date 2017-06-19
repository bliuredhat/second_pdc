### Allow pushing Docker images to CDN

This change adds support to Errata Tool for attaching Docker images to
advisories and pushing them to Pulp for later distribution via CDN. This is a
significant new piece of functionality for the release chain. There are
related updates for Pub and Pulp to support this.

This support reduces the amount of manual effort spent shipping updates to
Docker images and allows Docker-based updates to benefit from the same kind of
process management that RPM-based updates use now, instead of being published
using a manual process tracked with "text-only" advisories.

The number of Docker images shipped is expected to increase to over 500 within
a year, so streamlining this process is becoming increasingly important.

Docker builds from brew may be added to an advisory. The package mapping for a CDN
Docker repository must be setup to be able to push. Note that an advisory may
not contain both RPMs and Docker images.

The new features are documented in the [relevant section][dockerdocs] of the
User Guide. There is also an [introductory presentation][dockerintro] and a
[screenshot based demonstration][dockerdemo] showing how to configure a CDN
repository for Docker pushes and add a Docker image to an advisory.

[dockerdocs]:https://errata.devel.redhat.com/user-guide/docker-docker-support.html
[dockerdemo]:https://drive.google.com/open?id=1X-_4dgTl-Qd4ugTQAUhA5ztlITMlvwah3baOj3jx4l0
[dockerintro]:https://drive.google.com/open?id=1EwbiBNjCYTlHFklM9gg9oz7JqhzgvEu11r_EKZFmyJc
