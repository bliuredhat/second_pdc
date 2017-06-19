### Fixed live push script not setting advisory issue date

A bug in the command line push scripts was causing advisory issue dates to not
be correctly set when pushing advisories through the 'live_push.rb' script. In
the past this has resulted in needing to manually fix the dates and repush
advisories after Y-stream RHEL releases.

This patch introduces a new '--set-issue-date' option for the 'live_push.rb'
script which ensures that issue date is set. Running the script with this
option sets the issue date of advisories being pushed to current date.

(Note there is a related bug,
[Bug 1244994](https://bugzilla.redhat.com/show_bug.cgi?id=1244994) which aims to
fix the logic so that the date is correctly set by default for command line
pushes).
