### Fixed UI not refreshing after 'Add Comment'

Previously, on the advisory page, the UI would not automatically refresh to
display a new comment after submitting, if the comment contained text
automatically converted to Bugzilla or Errata Tool links.

This problem was caused by incorrect HTML escaping, which has been fixed.
