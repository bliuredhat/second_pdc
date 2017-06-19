### Provide product list in bug's comment for text-only RHSA

After shipping a security advisory, Errata Tool adds a comment to the relevant
bugs with a link to the advisory and a list of products where the issue has been
fixed. For example:

````
This issue has been addressed in the following products:


  < product list here >


Via RHSA-2010:0939 https://rhn.redhat.com/errata/RHSA-2010-0939.html

````

For text-only RHSAs the logic used to display the product list did not work and
the comments would be posted with an empty product list, which was confusing for
customers or anyone else reading the comments.

ET now provides an additional text field "Product Version Text" to provide
explicit product version information for closing comments. If no explicit
product version for text advisories is available, Errata Tool will try to deduce
the product version from the advisory's RHN channels and CDN repos and otherwise
fallback to the product name.
