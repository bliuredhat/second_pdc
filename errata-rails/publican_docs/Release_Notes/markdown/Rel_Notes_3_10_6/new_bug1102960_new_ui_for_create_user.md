### New web UI and API for user management

Previously the user administration UI required two separate steps to create a
user account and set the appropriate user roles. In Errata Tool 3.10.6 this
has been simplified so that an Errata Tool administrator, (typically an FLS
team member), can fill in both user details and roles at the same time when
creating a user.

The new UI also allows the creation of machine users, i.e users that
authenticate using a Kerberos keytab. These users previously had to be created
manually by a developer via the Rails console. Now they can be created
conveniently by an Errata Tool administrator via the web UI.

[![Creating a user](images/3.10.6/add_user.gif)](images/3.10.6/add_user.gif)

Additionally there is a new JSON API for managing users. This new API is documented
[here](https://errata.devel.redhat.com/rdoc/Api/V1/UserController.html).
