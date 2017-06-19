### Add an exception to RpmVersionCompare.compares

RpmVersionComapare.compares generally compared rpm versions following
alphabetical order which counted RPM release of 'el' as newer than 'ael'.
But, in the reality, RPM release with ael7b_1 is newer than el7_1.

This used to cause returning incorrect released package list. And now it's been
fixed by treating this as an exceptional case so that RPM files with ael7b_1
will show up instead of el7_1.
