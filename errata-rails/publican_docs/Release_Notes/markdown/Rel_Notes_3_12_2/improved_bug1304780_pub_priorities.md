### Improved priorities for push jobs

When Errata Tool triggers a push in pub, it may set a priority for the pub
task.

In this release, these priorities have been adjusted to ensure that pub
workers are most appropriately utilized:

 * production targets are now always more highly prioritized than staging
   targets

 * RHSA pushes are now always more highly prioritized than pushes for other
   types of errata.
