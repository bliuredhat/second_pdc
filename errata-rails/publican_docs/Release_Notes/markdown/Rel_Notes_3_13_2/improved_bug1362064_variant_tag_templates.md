### Docker tag templates may be associated with a variant

CDN package tag templates, used for configuration of docker tags, may now be
associated with a particular variant. The tag template will only apply if the
specified variant is pushed. Tag templates with no variant restriction will
apply regardless of variant.

This allows Errata Tool to apply the correct docker tags to docker images for
products such as OpenShift that ship different variants to the same CDN repo.
