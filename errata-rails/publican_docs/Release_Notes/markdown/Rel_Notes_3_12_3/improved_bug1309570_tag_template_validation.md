### Validation for CDN repository package tag templates

(Creating CDN repo to package mappings and associated package tag templates is
part of the work-in-progress support for pushing docker images and was shipped
recently, (see [Bug 1278656](https://bugzilla.redhat.com/1278656)), even
though full support for pushing docker images is not yet complete.)

CDN repository package tag templates, which are used for Docker packages, are
now validated to ensure they meet minimum/maximum length and consist of valid
characters. This should help prevent mistakes when the tags are created.

[![Tag validation](images/3.12.3/dockertags.png)](images/3.12.3/dockertags.png)
