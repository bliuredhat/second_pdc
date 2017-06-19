### Improved handling of post-push task failures

The handling of failures in non-mandatory post-push tasks has undergone several
improvements:

- Errata Tool now runs as many post-push tasks as possible, rather than stopping
  when the first error is encountered.

- The user who triggered the push is notified of the failures by email.

- The status of a job with post-push failures is set to "POST_PUSH_FAILED".
  (The previous behavior was to set to "COMPLETE".)

These changes help ensure that important failures in post-push tasks will be
noticed, while not blocking the progress of an advisory when unimportant
failures occur.

The handling of failures from mandatory post-push tasks has not been changed.
