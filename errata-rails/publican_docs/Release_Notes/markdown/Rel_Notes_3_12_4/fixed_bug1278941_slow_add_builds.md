### Fix slow validation while adding released packages

Previously, adding a large number of released packages to a product was slow
mainly due to the time it took to validate that the builds are actually
newer than what is already released. This has been optimised and the
validation should finish quickly. It now takes around six seconds instead of
several minutes to add 2500 builds to the released packages list.
