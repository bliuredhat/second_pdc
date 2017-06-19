### Set secure flag for session cookie

Errata Tool now sets the "Secure" flag on session cookies.  This
instructs the browser to only send the cookie when using HTTPS, thus
reducing the risk of leaking a session cookie over an unencrypted
connection.
