### Fix CVE/CPE to re-push OVAL and XML to errata-srt service

The PST team occasionally need to update CVE and CPE information for
advisories that have already shipped. Previously not all of these updates were
propagated automatically to the errata-srt service.

To address this, in Errata Tool 3.12.3 the 'Fix CVE' page now automatically
re-pushes the XML to the errata-srt service for CVRF if the CVE names are
replaced. Previously, only OVAL was pushed.

Additionally the 'Fix CPE' page now re-pushes both OVAL and XML to the
errata-srt service.

See also:
[Bug 1305977](https://bugzilla.redhat.com/show_bug.cgi?id=1305977)
