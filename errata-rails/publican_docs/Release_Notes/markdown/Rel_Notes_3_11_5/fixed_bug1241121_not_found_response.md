### Fix API response status for record not found errors

Errata Tool's JSON API now returns 404 (NOT FOUND) instead of 400 (BAD
REQUEST) when no resource could be found for the request.
