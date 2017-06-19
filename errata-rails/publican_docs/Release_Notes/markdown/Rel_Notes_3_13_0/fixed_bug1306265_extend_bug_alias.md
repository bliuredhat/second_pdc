### Limited alias column size can cause ET to not see all bug aliases

The existing bug alias column size (255 characters) permitted a
maximum of 17 CVE entries, assuming four-digit CVEs.  This size
limitation caused issues for some bugs with many associated CVEs; the
alias list for these bugs was truncated in Errata Tool.  To remedy
this, the column size has been extended to hold as many as 200 CVEs,
and assumes those to be five digits in length.  The new column size
for bug aliases is now 3200 characters.
