### Fix incorrect RPM id used to check signatures

Errata Tool was incorrectly using an internal record id to check if an RPM was
signed, instead of the RPM id used by brew, which caused problems checking
signatures in the case where the ids were different. (This bug was a
regression related to schema changes introduced to support attaching non-RPM
brew files to advisories).

It has been fixed in Errata Tool 3.11.3 and the correct id is now used to
check if an RPM has been signed.
