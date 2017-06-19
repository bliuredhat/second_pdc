### Do not show duplicate advisory and build details on package view page

Previously, Errata Tool would sometimes show duplicate rows in the Active
Errata and Shipped Errata tables on the Package view page, depending on
how many different file types were selected for each build.

This has been fixed; Errata Tool now shows only a single line per build
for each advisory.
