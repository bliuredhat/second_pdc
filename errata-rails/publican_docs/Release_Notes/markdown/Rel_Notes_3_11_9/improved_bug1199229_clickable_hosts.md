### Make host names clickable in TPS lists

When managing TPS tests for an advisory it's often useful to ssh into the
stable system that is running the TPS job to troubleshoot or resolve problems.

To make this easier, the stable system host names in the TPS job list have
been made into clickable links (with urls beginning with `ssh://`). If you
configure your browser with a suitable handler for the ssh protocol then you
can quickly shell in to the relevant stable system by clicking on the link.
