### Remove old deprecated push scripts

The push scripts in the Errata Tool bin directory (cdn_push.rb, ftp_push.rb,
live_push.rb, live_rhn_push.rb, stage_rhn_push.rb) are obsolete, and have been
removed.

Errata Tool supports pushing advisories through the [JSON API][PushApi]
(as well as through the web user interface).

[PushApi]: https://errata.devel.redhat.com/developer-guide/api-http-api.html#api-pushing-advisories
