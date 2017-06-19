Put release notes for the next release into this directory
as individual .md files per bug.

This allows preparing release notes during development without conflicts
due to all notes going to the same file.

Suggest naming like this:

  improved_bug12345_adjust_ui.md
  fixed_bug12346_avoid_crash_on_quux.md
  new_bug123457_add_frobnitz_support.md

Nothing automated processes these files, but they can be included in the main
release notes document. Late in the development cycle, somebody needs to move
them into the appropriate folder.

Put screenshots into the ../images/next_release/ directory.
