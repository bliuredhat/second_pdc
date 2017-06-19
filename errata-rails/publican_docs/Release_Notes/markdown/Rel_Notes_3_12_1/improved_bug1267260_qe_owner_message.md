### Send qpid message when QE owner is changed

Errata Tool will now publish a message on qpid when the QE owner of an advisory
is changed.

This message will be sent to `errata.activity.assigned_to` and will contain the
username of the previous and new QE owner.  See the
[Errata Tool qpid guide](https://docs.engineering.redhat.com/x/WT2nAQ) for more
information on qpid messages sent by Errata Tool.
