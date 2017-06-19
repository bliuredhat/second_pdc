### Find Brew builds using NVR, build ID or URL

This usability enhancement allows Brew builds to be added to an advisory by
specifying either the NVR, the build ID, or the Brew build URL. Previously,
only the NVR could be used.

It also fixes a bug, which caused a "500 Internal Server Error" to
be reported in some cases if a build was not specified using NVR notation.
