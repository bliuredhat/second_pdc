### Incorrect error message when adding builds via the API without properly specifying a build

When using the API to add builds to an advisory, previous versions of Errata
Tool would respond with a confusing 'undefined method DetailedArgumentError'
error message if the request parameters didn't correctly specify a build. This
has been fixed in in Errata Tool 3.11.0. Add builds requests with improperly
specified builds will now respond with the intended, more useful error
message, 'missing id or nvr'.
