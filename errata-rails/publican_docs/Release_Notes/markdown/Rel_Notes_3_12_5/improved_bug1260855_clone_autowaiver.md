### Provide a way to clone autowaiving rules

Users with the `secalert`, `releng`, `admin` or `devel` role are able
to create autowaiving rules. These users now also have permission to
clone autowaiving rules.

Users with the `qa` role have no permission to clone autowaiving
rules, and cannot see the 'Clone' button.

There are two places where users can clone an autowaiving rule:

* on the autowaiving rule list page, and
* when viewing an RPMDiff autowaiving rule.

#### Autowaiving rule list page

There is now a 'Clone' button in the action column.

Clicking on the 'Clone' button will pop up a new rule identical to the
rule being cloned except the new rule is not activated.

If the cloned rule was created from a particular test result, the new
rule will also include that information.

The new rule will have the same approval permissions as the cloned
rule, for example, if the developer has permission to approve the
cloned rule, they will be able to approve the new rule, and if the
developer does not have permission to approve the rule, they will
need to request approval from someone with the applicable permission.

After cloning, the creator can make changes as required and
save changes by clicking the 'Apply' button.

#### View RPMDiff autowaiving rule page

At the bottom of the view page there is a 'Clone' button that works
the same as described above.
