### Enable CORS headers for no authenticated end points

Browsers restrict cross-origin HTTP requests initiated from within scripts.
So, a web application using XMLHttpRequest or Fetch could only make HTTP
requests to its own domain. Previously it was not possible to make cross-origin
HTTP requests to non-authenticated endponts in Errata from a different domain.

For example, an HTML page served from http://somehost.redhat.com makes a GET
request for http://errata.devel.redhat.com/errata/get_channel_packages/1234?format=json
was not allowed.

This has been fixed and Errata now allows GET and OPTIONS (http verbs) for
non-authenticated endpoints by enabling CORS http headers if the
Origin (HTTP header) ends in redhat.com.
