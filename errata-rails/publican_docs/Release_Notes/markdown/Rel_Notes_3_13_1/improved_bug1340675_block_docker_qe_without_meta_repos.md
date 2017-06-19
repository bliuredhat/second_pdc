### Docker advisories blocked from moving to QE without metadata repos

Docker advisories require CDN repos to be selected for pushing metadata.
Previously, advisories could move to QE state without these repos being
set.

This has been changed; now, docker advisories must have metadata repos
selected before moving to QE state.
