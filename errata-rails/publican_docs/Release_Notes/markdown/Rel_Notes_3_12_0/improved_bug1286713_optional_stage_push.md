### Make stage push non-compulsory for RHEL-6.8 and RHEL-7.3

For RHEL-7.2 TPS-DistQA (i.e. TPS-RHNQA and TPS-CDNQA) testing was made
non-compulsory, see [bug
1229222](https://bugzilla.redhat.com/show_bug.cgi?id=1229222) for details.
This is configurable using a "workflow rule set" which can be applied to a
specific release.

Because stage pushes are often problematic and a source of delays, it's
acceptable to skip stage pushes when TPS-DistQA is not required. This did
not require a patch, but the creation of a new workflow rule set with the
stage push requirement set to non-blocking.
