### Reverted TPS actions back to individual buttons

[Bug 1229222](https://bugzilla.redhat.com/1229222) changed the TPS job results
view, presenting actions as a dropdown menu instead of individual buttons.
Although this improved page layout, user feedback indicates that individual
buttons are preferable to reduce the amount of clicking required.

This change restores the individual buttons, but does not revert the other
parts of bug 1229222 (in particular, the use of AJAX for the (re)schedule
actions is retained).
