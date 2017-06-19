### Fixed advisory description exceeding the RHN size limit in some cases

For historical reasons RHN requires that advisory description text does not
exceed 4000 characters in length. Errata Tool enforces this rule, but it was
doing so prior to the text being word-wrapped and having characters like angle
brackets and quotes encoded.

Since the formatting and encoding increases the total length of the
description text, in some cases it was exceeding the 4000 character size limit
which was causing errors to happen when pushing the affected advisory to RHN.

In Errata Tool 3.10.0 this is fixed by ensuring the size limit requirement is
enforced on the description text after the formatting and escaping is done
rather than before.

For further details see
[Bug 1032875](https://bugzilla.redhat.com/show_bug.cgi?id=1032875).
