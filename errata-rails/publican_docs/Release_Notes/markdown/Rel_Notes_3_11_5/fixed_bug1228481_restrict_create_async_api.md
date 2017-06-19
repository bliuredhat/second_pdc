### Restrict ASYNC advisory creation through API

Only users with the 'createasync' role may create ASYNC advisories
through the UI (see bug 1196317). This change enforces the restriction
further to prevent unauthorised users from creating ASYNC advisories
through the JSON API.
