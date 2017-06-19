### CCAT runs can now be re-scheduled

CCAT runs are automatically triggered once an advisory has been shipped live.
Yet, in cases of failed test runs, the re-scheduling ability of the test runs
was not possible to be triggered from within Errata Tool.

[![Re-scheduling a failed CCAT test run](images/3.14.3/bz1297555_ccat_reschedule.png)](images/3.14.3/bz1297555_ccat_reschedule.png)

With this version, Errata Tool provides a small menu item to re-schedule. Test
runs which can be re-scheduled have to have a Jira ticket associated and are in
a failed state.
