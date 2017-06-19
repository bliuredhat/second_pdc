### Ability to limit push targets in variant and package levels

Previously it was possible to configure push targets at the product and
product version level. In this release, push target configuration has been made
more fine-grained. It is now possible to specify required push targets for
variants, and for individual packages in a variant.

This feature is required to handle the new RHEL Extras variant which will be
added to the RHEL product. Extra variants will be used for "fast-moving"
technologies, such as docker client, upgrade tools, and kpatch. Those packages
will only work on systems that are using the new entitlement system.
Therefore, it does not make sense to deliver those packages to RHN since they
won't work on those systems.

By using this feature, Errata Tool administrators will be able to limit the
packages to push only to the specified targets, such as CDN.

Push target restrictions being applied to a variant:

[![variantrestrict](images/3.10.0/variantrestrict.png)](images/3.10.0/variantrestrict.png)

Push target restrictions being applied to an individual package:

[![pkgrestrict1](images/3.10.0/pkgrestrict1.png)](images/3.10.0/pkgrestrict1.png)

[![pkgrestrict2](images/3.10.0/pkgrestrict2.png)](images/3.10.0/pkgrestrict2.png)

[![pkgrestrict3](images/3.10.0/pkgrestrict3.png)](images/3.10.0/pkgrestrict3.png)

For more information see
[Bug 1085498](https://bugzilla.redhat.com/show_bug.cgi?id=1085498).
