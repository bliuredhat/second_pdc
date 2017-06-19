### Push OVAL and CVRF XML to Product Security for all advisories with CVE

Previously, Errata Tool would only push OVAL and XML data for CVRF to
Product Security for RHSAs. Sometimes, a CVE will be added to a shipped
non-security advisory, if it is found that the change fixes a security
issue. This meant that Product Security did not receive OVAL and XML data
for all advisories that had a security impact.

Errata Tool now sends OVAL and CVRF XML data for all advisories that have
a CVE, not just for RHSAs.
