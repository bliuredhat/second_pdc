### Improved workflow for RPMDiff autowaive rule approval

Previously, activaton of an RPMDiff autowaive rule needed to be performed by a
user with the `admin` role. This was inconvenient and often needlessly delayed
rule activation.

To address this the workflow has been revised as follows:

- Users with role `secalert`, `releng`, `admin` or `devel` have permission to
  create and edit autowaive rules.
- On the autowaive rule list page, any user who is able to create an autowaive
  rule also has the permission to activate or deactivate it.
- When an autowaive rule is created based on a particular RPMDiff result
  detail, the rule can be activated by the same users who can waive the
  RPMDiff result. For example, if the result can be waived only by `releng` or
  `secalert` users, the autowaive rule can be activated only by `releng` or
  `secalert` users. Similarly, if the RPMDiff result can be waived by the user
  creating the autowaive rule, then the user also has permission to activate
  the rule.
- For existing autowaive rules, users who have the permission to create an
  autowaive rule also have permission to activate or deactivate existing
  rules, (i.e. it no longer requires a ticket to request activation by an
  admin user).

Note that for an existing activated rule, users without permission to activate
the rule will not current be able to edit the rule.
