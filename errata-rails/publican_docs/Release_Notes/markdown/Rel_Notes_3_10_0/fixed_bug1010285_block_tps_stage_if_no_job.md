### Block TPS and RHNQA test stages when no job is scheduled

In cases where an advisory failed to properly schedule TPS jobs, Errata Tool
would incorrectly consider that the advisory had passed TPS. This was because
the criteria for passing was defined as "zero non-passing TPS jobs".

This has been fixed in Errata Tool 3.10.0. Advisories requiring TPS to be
passed will require that there is at least one TPS or RHNQA test job and that
all jobs are passed.

For more information see
[Bug 1010285](https://bugzilla.redhat.com/show_bug.cgi?id=1010285).
