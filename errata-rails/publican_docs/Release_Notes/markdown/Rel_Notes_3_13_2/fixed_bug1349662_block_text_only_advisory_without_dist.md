### Text-only advisory must set RHN Channel or CDN Repository

Previously, it was permitted for text-only advisory to be pushed without any RHN
channel or CDN repository. This would cause the public errata URLs for the
text-only advisories to have no content.

This has been fixed. New workflow prevents text-only advisory changing its
status from QE to REL_PREP without any of RHN channel or CDN repository.
