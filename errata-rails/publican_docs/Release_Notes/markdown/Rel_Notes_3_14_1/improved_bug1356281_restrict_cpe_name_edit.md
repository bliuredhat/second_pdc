### Restrict creation/editing of variant CPE to certain roles

Errata Tool now restricts which users can add a CPE to a variant to users
with the `secalert` or `admin` roles.

This change has been made to prevent problems caused by CPEs that do not
conform to the proper CPE conventions.
