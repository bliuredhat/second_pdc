Push Targets, Options and Tasks
===============================

Overview
--------

This section lists the available push targets, Pub options and pre/post-push
tasks supported by Errata Tool.

The description, as shown on the Push screen, is given for each task or
option. Note that the tasks shown on the Push screen are listed as "Push tasks"
and do not distinguish between pre- and post- push.

See the [Push APIs](#api-pushing-advisories) documentation for details of the
APIs supported by Errata Tool.

Push Targets
------------

The following push targets are supported by Errata Tool.

--------------------------------------------------------------------
Target             Description
------------------ -------------------------------------------------
`rhn_live`          Push to RHN Live

`rhn_stage`         Push to RHN Stage

`cdn`               Push to CDN Live

`cdn_stage`         Push to CDN Stage

`cdn_docker`        Push docker images to CDN

`cdn_docker_stage`  Push docker images to CDN docker stage

`ftp`               Push to public FTP server

`altsrc`            Push sources to CentOS git
--------------------------------------------------------------------


Pub Options
-----------

-------------------------------------------------------------------------
Option          Default Description
--------------- ------- -------------------------------------------------
`nochannel`     false   Skip subscribing packages (nochannel)

`push_files`    true    Upload errata files

`push_metadata` true    Push metadata / Submit errata to Red Hat Network

`shadow`        false   Push to shadow repos

`priority`      22      Priority of push job (for RHSAs, the default priority is higher)
-------------------------------------------------------------------------

Pre-Push Tasks
--------------

The following pre-push tasks may be specified, and will be run before the
advisory is pushed:

--------------------------------------------------------------------------
Task                 Description
-------------------- -----------------------------------------------------
`reset_update_date`  Set the 'updated date' to the issue date; Only set this when fixing a bad 'updated date'

`set_issue_date`     Set the 'issue date' to today; Only check this if this errata has previously been pushed live, yet you want to show today's date as the issue date

`set_update_date`    Set the 'updated date' to today; Only uncheck this for changes like adding a CVE name, typo fix, or to fix an infrastructure issue
--------------------------------------------------------------------------

### Mandatory Pre-Push Tasks

The following pre-push tasks are mandatory, and will always be run. They are
not shown in the Push screen and cannot be specified through the [Push APIs](#api-pushing-advisories),
but may be returned in API responses.

--------------------------------------------------------------------------
Task                 Description
-------------------- -----------------------------------------------------
`set_live_id`        Set a live ID for the errata

`set_in_push`        Puts the advisory in the `IN_PUSH` state
--------------------------------------------------------------------------

Post-Push Tasks
---------------

The following post-push tasks may be specified, and will be run following a
successful push:

--------------------------------------------------------------------------
Task                    Description
----------------------- --------------------------------------------------
`move_pushed_errata`    Call releng's move pushed errata script

`update_bugzilla`       Close the errata's bugs as CLOSED/ERRATA

`update_jira`           Close the errata's JIRA issues
--------------------------------------------------------------------------

### RHSA-specific Post-Push Tasks

The following post-push tasks apply only to RHSAs:

--------------------------------------------------------------------------
Task                    Description
----------------------- --------------------------------------------------
`push_oval_to_secalert` Push OVAL to secalert

`push_xml_to_secalert`  Push XML to secalert for CVRF

`request_translation`   Request translation of errata text
--------------------------------------------------------------------------

### Mandatory Post-Push Tasks

The following post-push tasks are mandatory, and will always be run. They are
not shown in the Push screen and cannot be specified through the [Push APIs](#api-pushing-advisories),
but may be returned in API responses.

--------------------------------------------------------------------------
Task                    Description
----------------------- --------------------------------------------------
`check_error`           Change the status of errata to `REL_PREP` if error occurred

`mark_errata_shipped`   Change the status of errata to `SHIPPED_LIVE`

`update_push_count`     Increase the push count by one
--------------------------------------------------------------------------
