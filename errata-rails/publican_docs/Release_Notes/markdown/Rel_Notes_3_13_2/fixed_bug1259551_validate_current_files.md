### Disallow builds without current files

When a build is added to an advisory, Errata Tool keeps a record of the files
associated with that build, known as "current files". In rare cases where those
records were not created correctly the advisory's file list would be reported
incorrectly in some places. This caused hard to find problems since the files
were still visible in the builds tab.

This issue has been fixed by adding a test that prevents advisories from moving
to QE if their current files records were missing. Errata Tool will advise that
the files need to be reloaded to fix the problem.

[![Reload builds for current files link](images/3.13.2/reload_current_files.png)](images/3.13.2/reload_current_files.png)
