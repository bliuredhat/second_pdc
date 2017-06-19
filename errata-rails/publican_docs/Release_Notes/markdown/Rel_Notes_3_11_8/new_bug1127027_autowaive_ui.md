### Manage Autowaive Rules for RPMDiff

A simple UI to manage autowaive rules has been added. These rules
are part of the RPMDiff project and will allow developers to create
waivers for recurring, known defects of packages. Rules created by
developers are inactive by default; only Errata Tool admins can review
and activate them.

Previously, genuine false positives needed to be waived every time a
build is analyzed. This was very time consuming, which is why this
mechanism has been implemented.

[![listautowaive](images/3.11.8/list_autowaivers.png)](images/3.11.8/list_autowaivers.png)

The recommended way of creating new rules is from the RPMDiff test
result page of each advisory. You will find a link on the bottom of the
page which brings you straight to the auto-waive form, prefilled with
criteria retrieved from the test result.
(Note: this link will only be displayed for RPMDiff results recorded
after RPMDiff 3.0 is released, expected during November.)

Rules can be edited by developers as long as they are not activated.  Send an
email to `errata-requests@redhat.com` once you are finished editing the rule, so
that they can be activated by an Errata Tool administrator.

[![edit_autowaiver](images/3.11.8/edit_autowaiver.png)](images/3.11.8/edit_autowaiver.png)

Deactivation of rules can only be performed by an Errata Tool administrator.

For more information, please see
[Bug 1127027](https://bugzilla.redhat.com/show_bug.cgi?id=1127027)
