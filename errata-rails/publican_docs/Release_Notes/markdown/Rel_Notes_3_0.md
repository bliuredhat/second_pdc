Release Notes for Version 3.0
=============================

## Overview

The 3.0 release of Errata Tool focusses mainly on implementing more flexible
and configurable advisory workflow. The goal of this is to implement different
advisory requirements depending on the product or release. The specific
requirements are driven mainly by the upcoming RHEL7 dry runs.

The release also contains some other new functionality bug fixes and was
deployed to production on October 31st, 2012.

### Related Resources

* [PRD document for Errata Tool Release 3.0](https://dart.qe.lab.eng.bne.redhat.com/RAP/en-US/Errata_Tool/3.0/html/PRD/index.html)

* [Bug List for Errata Tool Release 3.0](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.0%2B)


## Configurable Workflow
The 3.0 release of Errata Tool now supports configurable workflows on a per product and per release basis.

### Overview
Up until now, the workflow for every product and release was exactly the same:

* NEW\_FILES => QE requires rpmdiff
* QE => REL\_PREP requires Tps and TPS Rhnqa testing, RHN Stage pushes
* Documentation approval required for any movement beyond QE
* Etc

The errata system now allows these transition guards to be configurable. Tests can
completely block an advisory from moving forward, be waivable by certain groups, or
be informational warnings only.

The default RHEL process would require that rpmdiff be run and passed before transitioning
from NEW\_FILES to QE. Looking at the summary for such an advisory, one can see it is using
the Default rule set.

[![Default Summary](images/rel30/summary_default.png)](images/rel30/summary_default.png)

Following the link for the rule set will show a list of all the rules that apply in order for the current
state to transition to the next.

[![Default NEW\_FILES Step ](images/rel30/default_new_files.png)](images/rel30/default_new_files.png)

Following the link to the Default rule set will bring one to a page describing the entire set of rules.

[![Default Rule Set ](images/rel30/default_rule_set.png)](images/rel30/default_rule_set.png)

Alternately, a rule set can be set up which, aside from file and shipped live requirements, 
is totally unrestricted for state transitions.

[![Unrestricted Rule Set ](images/rel30/unrestricted_rule_set.png)](images/rel30/unrestricted_rule_set.png)

### Expected Use Cases for RHEL 7

For RHEL 7 development, we expect to use multiple rule sets as we get closer to RHEL 7 GA. We may start out with
an unrestricted rule set, allowing build sets to be added and tested easily. After devel freeze, we may start
requiring RPMDiff, TPS and/or Coverity runs. These will possibly start out as information only rule sets, like
the following:

[![Summary Info ](images/rel30/summary_info.png)](images/rel30/summary_info.png)

Note that this advisory is in REL\_PREP, despite RPMDiff and TPS not having run successfully. Looking
at the comments on NEW\_FILES => QE, one can see that a warning was issued about RPM Diff, but the
advisory was allowed to pass.

[![NEW_FILES => QE Info Warning ](images/rel30/new_files_qe_info_rpmdiff.png)](images/rel30/new_files_qe_info_rpmdiff.png)

Likewise, the same is true for TPS in the QE => REL\_PREP transition:

[![QE => REL\_PREP Info Warning ](images/rel30/qe_rel_prep_info_tps.png)](images/rel30/qe_rel_prep_info_tps.png)

Looking at the rule set being used, one can see that the TPS and RPM Diff tests are there, but are marked as 'Info'.

[![Info Rule Set ](images/rel30/info_rule_set.png)](images/rel30/info_rule_set.png)

## Non-RHEL CDW Flags

The flag names for the CDW's /three-ack/ flags have previously been hard coded
as `dev_ack`, `pm_ack` and `qa_ack`. Being able to use different flags for
different products allows more flexible use of the CDW. In particular, because
Bugzilla manages flag permissions based on the flag only, different flags are
required in order to configure different user permissions for flags.

To support using different flags names for different products, there is now a
mechanism in Errata Tool to add a per-product prefix to the three-ack flags.
This is done in Errata Tool via the web UI Admin. When editing or creating a
new Product, there is a field where a flag prefix can be added. The prefix is
added to the flag names, for example, adding a prefix of 'foo' would result in
Errata Tool using the flags `foo_dev_ack` and so on.

Initially this prefix will be used only by HSS for it's trial roll-out of CDW
for its internal systems such as Orgchart, Publican and Bugzilla, though it
may be used in the future for other purposes.

## CPE Support for Text-only Advisories

The CPE text is based on an advisory's builds. Because text-only advisories
don't have builds, their CPE text was blank. In release 3.0 Errata Tool
supports adding a CPE text field to text-only advisories. The text is added
manually when the advisory is created or edited while the advisory is in
status NEW\_FILES.

The manually entered CPE text for text-only advisories then appears in the
output of the `rhsa_map_cpe` XML-RPC method used by SecAlert along-side the
normal CPE text generated for non-text-only advisories.

## Miscellaneous Fixes and Improvements

Release 3.0 contains a number of miscellaneous improvements and bug-fixes. For
details, please see section 1.1.11 of the [PRD](https://dart.qe.lab.eng.bne.redhat.com/RAP/en-US/Errata_Tool/3.0/html/PRD/index.html)
or the [bug list](https://bugzilla.redhat.com/buglist.cgi?f1=flagtypes.name&o1=substring&v1=errata-3.0%2B).
