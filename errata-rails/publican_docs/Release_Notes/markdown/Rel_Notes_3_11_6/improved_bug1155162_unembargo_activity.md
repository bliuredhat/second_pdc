### Make status changes of embargoed errata visible on qpid

Errata Tool
[publishes qpid messages](https://docs.engineering.redhat.com/x/WT2nAQ) when an
advisory changes state.

In previous versions of Errata Tool, if an advisory was embargoed, these
messages would only be published to a restricted qpid topic with limited access.

This has been changed; status change messages (errata.activity.status) are now
always published to the unrestricted qpid topic, even for embargoed errata.
This allows improved integration with QE tools which need to test all errata,
including embargoed errata.

The behavior for messages other than errata.activity.status has not been
changed.
