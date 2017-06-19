### Add missing attribute to user API

When fetching details about an Errata Tool user via the HTTP/JSON API, (as
documented [here](https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-users)),
the 'receives_mail' attribute was missing from the response.

This has been fixed; the missing attribute is now present in the API response
for a user.
