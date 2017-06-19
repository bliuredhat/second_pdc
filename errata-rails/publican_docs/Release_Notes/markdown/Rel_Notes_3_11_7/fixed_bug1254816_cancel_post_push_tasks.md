### Fixed post-push tasks running on cancelled push job

In previous versions of Errata Tool, if a push job was cancelled via the UI
after the pub push had completed and post-push tasks were scheduled or started,
the post-push tasks would still be run despite the cancellation.

This has been fixed.  Post-push tasks are no longer run if a job was cancelled,
as expected.
