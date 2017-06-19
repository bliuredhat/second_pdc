### Allow admin users to remove released packages

Errata Tool maintains lists of released builds and provides a mechanism to add
builds to those lists. The released packages lists are used to provide base
nvrs for TPS, amongst other things.

Previously however there was no way to remove builds from the lists. When it
was necessary to remove a build, it could only be done by creating a ticket to
request it be removed manually by an Errata Tool developer.

In Errata Tool 3.10.2 this is addressed. It is now possible for rel-eng or
admin users to remove builds from the release packages lists via the web UI.

[![Removing released packages 1](images/3.10.2/delrelpkgs1.png)](images/3.10.2/delrelpkgs1.png)

[![Removing released packages 2](images/3.10.2/delrelpkgs2.png)](images/3.10.2/delrelpkgs2.png)
