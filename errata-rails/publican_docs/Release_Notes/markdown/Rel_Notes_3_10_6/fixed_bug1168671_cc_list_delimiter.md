### Fixed CC list rendered incorrectly

On the advisory details page, a formatting bug caused the CC list to
be displayed incorrectly.  When more than one user was on the CC list
for an advisory, the displayed usernames would be incorrectly combined
into a single string with no delimiter.

This was a regression introduced in Errata Tool 3.10.4.0, and has now
been fixed.
