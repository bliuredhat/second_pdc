### Support skipping DistQA TPS testing for RHEL 7.2

DistQA (i.e. RHNQA & CDNQA) TPS testing is an expensive part of the advisory
process, especially for releases with a high number of errata and
dependencies. Therefore it doesn't scale well for RHEL 7.2 which has a
particularly large number of advisories.

Because of this, the TPS-RHNQA testing for RHEL 7.2 will be handled outside of
Errata Tool by the Release Test Team (RTT).

This update allows Errata Tool to support configuring an advisory workflow to
skip DistQA TPS testing. It will still create all applicable DistQA TPS jobs
but not automatically schedule them, and incomplete tests will not block an
advisory from progressing to REL_PREP.

Quality Engineers are still able to schedule the available DistQA TPS jobs
manually in Errata Tool if required.

See [here](https://wiki.test.redhat.com/RhelQe/Rhel72/TpsRhnQa) for more
information about TPS-RHNQA in RHEL 7.2.

[![Unblock DistQA TPS](images/3.11.6/unblocking_distqa_tps_test.png)](images/3.11.6/unblocking_distqa_tps_test.png)
