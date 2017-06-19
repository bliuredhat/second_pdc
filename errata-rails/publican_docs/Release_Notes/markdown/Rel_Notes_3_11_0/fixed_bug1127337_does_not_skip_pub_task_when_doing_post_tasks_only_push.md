### Fixed unnecessary pub task run when rerunning CDN post-push tasks

Previously, Errata Tool would still run a Pub task even if the user had already unchecked both
'Upload errata files to CDN' and 'Push metadata' CDN push options. This would
cause unnecessary and time-consuming repo regeneration.

In Errata Tool 3.11.0 this issue is fixed.
