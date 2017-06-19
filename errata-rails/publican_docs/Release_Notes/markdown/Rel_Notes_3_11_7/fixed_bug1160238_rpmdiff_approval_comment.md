### Fixed RPMDiff QE review comments unused

In Errata Tool, RPMDiff waivers may be reviewed and approved or rejected by QE
users.

Previously, any comments supplied while approving an RPMDiff waiver were not
stored or displayed in the user interface.

This has been fixed.  Approval comments are now recorded and displayed in most
places where RPMDiff waivers are shown.

[![RPMDiff approval comments](images/3.11.7/rpmdiff_qe.png)](images/3.11.7/rpmdiff_qe.png)

Additionally, this fix corrected a few minor usability issues with RPMDiff
waivers, including bugs [1254540](https://bugzilla.redhat.com/1254540) and
[1255220](https://bugzilla.redhat.com/1255220).
