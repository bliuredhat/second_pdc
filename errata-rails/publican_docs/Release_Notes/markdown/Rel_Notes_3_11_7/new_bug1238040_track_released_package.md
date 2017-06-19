### Create audit record when adding released packages

Previously it was not possible to track the user, reason, and the contents
provided by users when adding new released packages through the
[Web UI][AddRelPkg].  With this feature, users must now provide a reason for
adding released packages to a product version.  The [default page][RelPkgList]
now shows `Added By`, `Reason`, and `Created At` for every released package listed
in the table.

[![Released Packages](images/3.11.7/released_package_audit.png)](images/3.11.7/released_package_audit.png)

(Note that the changes to the released package UI may impact scripts using this
form to add released packages. Please check the bug for more
information. Additionally, maintainers of scripts posting to Errata Tool forms
are encouraged to [file an RFE][FileApiBug] for the addition of APIs supporting
their use-case.)

[AddRelPkg]: https://errata.devel.redhat.com/release_engineering/add_released_package
[RelPkgList]: https://errata.devel.redhat.com/release_engineering/released_packages
[FileApiBug]: https://bugzilla.redhat.com/enter_bug.cgi?product=Errata%20Tool&component=API
