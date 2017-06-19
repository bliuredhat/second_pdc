RPMDiff
=======

Overview
--------

RPMDiff is a tool used in the Red Hat release process. It compares
and analyzes builds, looking for potentially harmful packaging
problems such as compiler warnings, changes in file permissions,
insecure binaries, Multilib conflicts, changes in specfile patches,
and many more.


How to Get More Information About a Test Failure
-----------------------------------------------

Each test result provides a link to our Wiki which provides in depth
information about the particular test, known problems and what you can
do to acknowledge known problems.

[![rpmdifftestinfo](images/rpmdiff/testinformation.png)](images/rpmdiff/testinformation.png)

A list of tests carried out by RPMDiff and their descriptions can also
be found on our [confluence
page](https://docs.engineering.redhat.com/display/HTD/Individual+test+descriptions+-+rpmdiff).


Waiving Test Results Automatically
----------------------------------

You can waive test results automatically by creating a new Autowaive
Rule.

Before you create a rule to waive a particular result, please
remember that rules will always target individual lines in an RPMDiff
test result, never the entire test. Your goal is not to waive the entire
test, but to only create rules which match results from RPMDiff you
know can be ignored.

<note>

The test results will show a link to similar autowaiving rules
created by other users to avoid creating rules to waive the same errors.

</note>

#. Navigate to the RPMDiff test which is not Passed.
#. Click on the link "Create Autowaive Rule" located next to each line
of the result log.
[![editrule](images/rpmdiff/editrule.png)](images/rpmdiff/editrule.png)
#. The edit form allows you to specify the rule criteria. Most items the
rule will filter on is already pre-selected for you. You may add/change
the product versions and regular expression. Please also give a reason as
to why this rule should be enabled for the approver.
#. Apply the rule and contact
[errata-requests@redhat.com](mailto:errata-requests@redhat.com) to activate it.

### Tips for Writing Good Rules


Here is a list of best practices to write good rules:

* Keep the regular expression as specific as possible to avoid
  automatically waiving a genuine problem. Don't use ``.*``, unless
  really necessary.

* Be mindful of the regular expressions being used and how they match.
  The rules use [Python Regular
  expressions](https://docs.python.org/2.6/library/re.html#re.RegexObject.search)
  and match anywhere in the RPMDiff output.

* Be mindful of wild card matches in your regular expression, since it
  can affect performance. Instead of `match.*this.*item`
  specify a reasonable upper bound: `match.{0,100}this.{0,100}item`.

* Provide a good reason to the approver avoiding long discussions about
  the eligibility of the rule.

* Keep the list of product versions for this rule as short as possible.
