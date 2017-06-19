### Block text only advisories with missing CDN/RHN repos when they are required

Text only advisories sometimes require CDN and/or RHN repos to push. Currently
there is nothing stopping a CDN/RHN push if they are missing, resulting in
errors.

This patch adds a state transition check to prevent moving to IN_PUSH,
which will also be displayed to the user as a push blocker.

