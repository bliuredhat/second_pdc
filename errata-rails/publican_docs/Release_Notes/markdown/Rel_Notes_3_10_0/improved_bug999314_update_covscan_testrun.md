### Allow refreshing the status of Covscan test runs

Errata Tool provides new functionality to manually update the status of a
Covscan result. It can be found among other actions for each test result
located by clicking on the *Covscan* tab for an advisory.

This is useful in cases where there has been a message bus outage or some
other interruption in communications with Covscan causing test run status
update messages to be missed. If Errata Tool's status information for a test
run is stale, it can now be easily re-synced with Covscan.

The Covscan tab shows a table with status information for each test run.
Actions are grouped into a drop down which is placed at the end of each row.

[![covscan1](images/3.10.0/covscan1.png)](images/rel310/covscan1.png)

The buttons to reschedule or refresh the status are also now available when
viewing a single Covscan test run.

[![covscan2](images/3.10.0/covscan2.png)](images/rel310/covscan2.png)

For more details please see
[Bug 999314](https://bugzilla.redhat.com/show_bug.cgi?id=999314).
