### Fixed pushes failing with "Cannot find a push job with pub task id"

Pub tasks initiated from earlier versions of Errata Tool could sometimes
incorrectly fail with a message of "Cannot find a push job with pub task
id=(id)".  This issue could be triggered if pub attempted to work on a newly
created task before Errata Tool had committed the related push job to its
database.

This occurred most often when attempting to trigger multiple push types in a
single request using the API.

This has been fixed by adjusting the use of transactions in Errata Tool.
