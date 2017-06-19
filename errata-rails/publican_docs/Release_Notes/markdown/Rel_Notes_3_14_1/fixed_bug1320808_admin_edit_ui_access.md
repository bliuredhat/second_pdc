### Remove edit links/buttons from some admin screens if not permitted

Errata Tool allows most users read-only access to administration screens,
but only permits certain users to change details on these pages. A user
without permission to perform these functions should receive an error
message if they attempt to do so, although in some cases the page will
appear to be stuck loading.

This change removes edit-related links and buttons for users that do not
have permission to use them.
