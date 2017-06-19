### Prevent advisories with multi-product file list problems from leaving NEW_FILES

For multi-product advisories with broken file listings, nothing prevents them from
leaving the NEW_FILES state. This has led to several problems down the line.

This fix adds a test to the build transition guard to check for such problems. If
present, the advisory is prevented from leaving NEW_FILES, and an appropriate error
message is shown to the user.

