### Avoid duplicate errata brew mappings and files

Sometimes Errata Tool shows duplicate files for an advisory, for example
in the advisory text or builds screen.

This is caused by duplicate ErrataBrewMapping and/or ErrataFile objects in
the Errata Tool database. These can get created due to race conditions that
are difficult to avoid with the existing schema.

This change works round the problem, by only selecting the most recent
ErrataBrewMapping or ErrataFile objects, when there are duplicates.
