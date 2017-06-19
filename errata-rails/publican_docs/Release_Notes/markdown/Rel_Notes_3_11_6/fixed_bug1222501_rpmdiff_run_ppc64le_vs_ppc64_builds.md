### Fix RPMDiff comparing ppc64le builds to non-ppc64le builds

Ppc64le builds in Red Hat Enterprise Linux Supplementary advisories were in
some cases mistakenly compared to non-ppc64le builds in scheduled RPMDiff tests.

Errata Tool was taking the variant into account when searching for previous
runs to schedule a comparison run, which was causing problems since the
LE and non-LE product versions have the same variant.

This is now fixed. The scheduler now considers the product version as well as
the variant in order to prevent comparisons with the wrong package.
