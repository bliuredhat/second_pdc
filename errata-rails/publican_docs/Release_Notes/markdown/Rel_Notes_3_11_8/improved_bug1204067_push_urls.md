### Prefer `push/` instead of `rhn/` for push URLs

This change fixes an issue that caused all push URLs to include `rhn`,
even for non-RHN push jobs. Both URL forms continue to work, but the
`push` path is now preferred.
