###  Render escaped RPMDiff result output on manage waivers view

The manage waivers view in Errata Tool accessed a deprecated column in RPMDiff
which caused sometimes invalid HTML to make the manage waivers form to
disappear. The view now accesses the correct result rows which leads to
correctly escaped HTML output.

