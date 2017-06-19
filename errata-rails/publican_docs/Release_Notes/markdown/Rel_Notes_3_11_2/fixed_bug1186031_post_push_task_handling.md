### Fixed logging and error handling when running push tasks

Some problems with push job logging and error handling have been
resolved:

* Log messages are now updated in real-time, ensuring that messages
  are not lost.  Previously, push job log messages could be lost in
  certain rare situations.

* Error handling has been improved so that the details of errors are
  reliably logged.

* Interrupting a push job during task execution now works as expected.
  Previously, some incorrect error handling code caused push job
  execution to be uninterruptible, which caused the system to behave
  unpredictably when push tasks timed out.
