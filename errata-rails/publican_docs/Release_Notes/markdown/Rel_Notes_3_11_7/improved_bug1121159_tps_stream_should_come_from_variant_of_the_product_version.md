### Determine TPS stream from the variants of the product versions applicable to an advisory

Previously, while scheduling TPS jobs, the TPS stream was determined from the
variant that the RHN channel or CDN repository belongs to.

'AUS' and 'EUS' RHN channels/CDN repositories were normally created during the
Z-stream release. Since these repositories belong to a Z-stream release, their
TPS streams would become incorrect for the 'AUS' and 'EUS' releases
later. Hence, this caused some TPS jobs failing to start.

This issue has been fixed by determining the TPS stream based on the variant of
the product version applicable to the advisory.

In order to determine whether the TPS streams are valid in TPS server, Errata
Tool periodically syncs the information with TPS server.

[![Sync TPS Streams](images/3.11.7/sync_tps_streams.png)](images/3.11.7/sync_tps_streams.png)

Additionally, warning messages have been added to the TPS scheduling page to
help troubleshoot not started TPS jobs.

[![No Stable System Warnings](images/3.11.7/tps_no_stable_systems.png)](images/3.11.7/tps_no_stable_systems.png)
