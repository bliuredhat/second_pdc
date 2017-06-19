### CDN Docker repository name allows dot characters

Docker Pulp permits the '.' character in repository names. Previously,
Errata Tool would reject repository names containing this character for
all CDN repository types.

This has been changed to allow Docker repos to contain '.' characters.
Other repository types are not affected, and the existing restrictions
still apply.
