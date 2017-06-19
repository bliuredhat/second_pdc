### Disallow '.' and '/' in CDN Repository Names

Errata Tool should not allow CDN repository names to contain any '.' and '/'
characters because neither of them are allowed in Pulp Repository labels.
The convention in Pulp is to use '__' for '/', and '\_DOT\_' for '.'. CDN
repository names with invalid characters will also cause TPS test failures
because they are never seen by TPS.

This has now been fixed. Additionally, the text 'Repo Name' is replaced with
'Pulp Repo Label' to avoid misunderstanding and there is some explanation text
to make it easier to choose the right name when creating a CDN repository.
