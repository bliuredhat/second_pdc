### Block text-only advisory without dists

Previously, text-only advisories without RHN channel or CDN repository were
prevented transitioning the state from QE to REL_PREP but once transitioned
to REL_PREP removing RHN channel or CDN repository was allowed again and it
would still be problematic where advisories require RHN channel or CDN
repository during or after release time.

This has been fixed. Additional transition guards were added for the state
transitioning from REL_PREP to PUSH_READY to ensure to have at least one RHN
channel or CDN repository.
