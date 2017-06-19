### Require the 'pusherrata' role for pushing to CDN/Pulp

Errata Tool allows users with the `pusherrata` role to push content to RHN
live. But for pushes to CDN live it incorrectly allowed any user to perform
content pushes.

This has been fixed in Errata Tool 3.10.4. Now the `pusherrata` role is
required for pushing content to both RHN live and CDN live.

Note that the restriction does not apply for stage pushes, so users do not
require the `pusherrata` for pushes to RHN stage and CDN stage.
