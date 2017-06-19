### Don't hang when sending a Qpid message if the server is unresponsive

If the Qpid server is unresponsive it can cause Errata Tool to hang
indefinitely when attempting to send a message. Because messages are sent
using the background job worker, if the worker hangs then job queue
processing is blocked, and a lot of critical Errata Tool functions stop
working.

This is fixed by configuring the Qpid client to use a "heartbeat". The client
will drop the connection once two heartbeats are missed, so the send message
job fails and the background job worker is not blocked. (Failed send message
jobs will be retried later.)

Thanks very much to Jon Orris for helping diagnose and solve this problem.
