### Support sending messages to Unified Message Bus (UMB)

Errata Tool now supports sending messages to the Unified Message Bus,
it will replace the current Qpid, and during the transition period,
the messages will be posted to Qpid as well as UMB topic.

It's important to note that we have some message format changes
on UMB. You can read more about the changes on the Developer Guide:
[UMB Messaging](/developer-guide/umb-umb-messaging.html)