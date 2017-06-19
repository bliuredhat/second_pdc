### Fixed errata created using wrong solution

When creating an advisory, Errata Tool supplies a default value for the
"solution" field based on the product of the advisory.

Previously, if a user changed the selected product on the advisory creation form
after it had initially loaded, the "solution" field would not be reinitialized
with the appropriate value for the newly selected product.  This could lead to
the advisory being created with the wrong solution.

This has been fixed.
