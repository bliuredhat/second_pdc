### Allow re-push of XML to secalert for CVRF

A new menu option has been added for shipped RHSA errata, which repushes XML
to the errata-srt service for CVRF (Common Vulnerability Reporting Framework).

This menu option can be found in the "More" menu, for relevant advisories. It
is accessible only by users with the `pusherrata` or `secalert` roles.

This allows the security information to be updated without requiring a re-push
of the entire advisory.

[![Re-push XML](images/3.12.3/pushsecalert.png)](images/3.12.3/pushsecalert.png)
