### Block push if docker images are untagged

Errata Tool now prevents docker advisories from being pushed, if any of
the packages do not have tags configured in the appropriate repositories.

More information on how to configure tags can be found in the
[Errata Tool User Guide](https://errata.devel.redhat.com/user-guide/docker-docker-support.html#docker-configuring-docker-tag-templates).
