### Fixed incorrect rails logs rotation caused by delayed job

Previously, Errata Tool's delayed job worker would attempt to redirect
all log messages to its own log file.  This caused other log files to
unexpectedly rotate when the delayed job log reached its maximum
configured size.

This has been fixed by removing the log file redirection.
