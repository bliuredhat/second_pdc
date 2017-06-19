### Restore searchable user lists in advisory modal dialogs

This change fixes a regression caused by the introduction of asynchronously
loaded modal dialogs in [Bug 1221863](https://bugzilla.redhat.com/show_bug.cgi?id=1221863).

The drop-down selectors in some of the modal dialogs (Change QA Owner/Group
and Change Docs Reviewer) used the generic style instead of the enhanced
"chosen" style (with searchable selectors).

This fix was earlier deployed in the Errata Tool 3.11.8.1 hotfix release.