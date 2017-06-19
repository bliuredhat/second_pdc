### Multipush only jobs with matching Pub options

Errata Tool may combine multiple push jobs for the same target into batched
multipush requests to improve performance. Pub requires jobs in a multipush
to have the same Pub options, and Errata Tool did not take this into account.
In particular, Docker push requests to CDN usually have different Pub options
to those used by RPM advisories. This would result in push failures.

This has been fixed. Errata Tool will now only combine push jobs that have
both the same target and same Pub options into multipush requests.
