### Added HTTP security headers to response

This change improves the security of the Errata Tool application,
by adding the following headers to all HTTP responses:

-   `X-Content-Type-Options`
-   `X-Frame-Options`
-   `X-XSS-Protection`

These headers are described in
[List of useful HTTP headers](https://www.owasp.org/index.php/List_of_useful_HTTP_headers).
