### Fixed obsoleting old builds when a new build is added

A regression introduced in Errata Tool 3.10.0 due to some refactoring to
support non-RPM files caused builds to not be properly obsoleted when a new
build was added.

This was fixed in Errata Tool 3.10.0.3 which was shipped live on 19 September.
