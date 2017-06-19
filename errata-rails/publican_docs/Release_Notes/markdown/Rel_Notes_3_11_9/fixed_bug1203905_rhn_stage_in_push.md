### Fixed RHN Stage displayed as blocked for IN_PUSH advisory

In previous versions of Errata Tool, while an advisory was `IN_PUSH` (i.e. a
live RHN or CDN push was in progress), the "Push to RHN Staging" workflow item
would incorrectly be displayed as red (blocked) even if the advisory had been
pushed to RHN stage successfully.

This has been fixed so that a completed RHN stage push displays correctly as
green (passed).

[![rhn stage display](images/3.11.9/1203905.png)](images/3.11.9/1203905.png)