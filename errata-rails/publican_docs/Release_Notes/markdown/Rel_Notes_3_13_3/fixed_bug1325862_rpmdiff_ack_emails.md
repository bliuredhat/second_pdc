### RPMDiff waiver ack email subject changed

The emails sent by Errata Tool when RPMDiff waivers are approved (acked) or
rejected (nacked) have been updated. Previously, the subject of these emails
included the text "RPMDiff results UN-waived", which was misleading as the
waivers may have been approved.

This text has been changed to "RPMDiff waiver status updated" as this more
accurately describes the action which resulted in the email.

The ACTION-HEADER in the email has also been updated, from "UNWAIVED" to
"ACK-UPDATE".
