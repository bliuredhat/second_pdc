### Fixed missing validation on product edit form

The form for editing a product was missing a validation on the state
machine rule set.  An attacker could exploit this to set the rule set
for a product to null, effectively causing a Denial of Service for
that product.

This has been fixed by adding the missing server-side validation.
