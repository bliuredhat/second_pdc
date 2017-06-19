### Faster opening of Releng initial screen

Previously, when opening the Releng screens, the Browse Released Packages tab
would be shown, populated with RHEL-6 builds. This took some time to generate
(over 2000 builds) and was unlikely to be of use to most users.

This has been changed, so no Product Version is selected, and no packages are
displayed by default.
