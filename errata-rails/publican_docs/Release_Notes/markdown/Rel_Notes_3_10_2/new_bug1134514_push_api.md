### API improvements and additions for pushing advisories

In order to support a use-case for automated RHEL Atomic OSTree
updates, several additions and improvements have been made to Errata
Tool's API.  This included fixing some minor gaps in the existing API
and adding entirely new APIs for triggering advisory pushes and
manipulating text-only channels/repos.

* Docs may be approved or disapproved
  [via an updated API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html#method-i-update).
* Advisories may be pushed to pub
  [via a new API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumPushController.html).
* Text-only channels/repos may be set
  [via a new API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumTextOnlyController.html).
* Advisories may be closed or reopened
  [via an updated API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html#method-i-update).

With these updates, it is now possible to create a text-only advisory
and move it through the entire Errata lifecycle using only the API.
