### Fixed missing latest released packages

Previously, Errata Tool didn’t know about the latest released packages from
the adjacent stream which had been inherited automatically. Thus, it would
either report the wrong package or not report any last released package
when it should do so.

Missing released packages cause TPS testing to fail for affected advisories.
The missing packages can be added manually, but this is time consuming and
inconvenient. Requests to manually add released packages in Errata Tool make
up a large portion of Errata Tool ticket queue requests, so reducing the
frequency of these requests should bring significant benefit.

A number of improvements were made related to the method used to identify
released packages. Typical scenarios are described below:

* An X.Y.0 erratum is filed. There was a shipped X.Y-1.Z erratum. Packages that
  were released from the latter erratum (z-stream) should be reported as old
  packages by Errata Tool.
* An X.Y.Z erratum is filed. There was a shipped X.Y.0 erratum. Packages that were
  released from the latter erratum (main stream) should be reported as old packages
  by Errata Tool.
* A layered product erratum is filed. Packages that were released to the base
  channel or CDN repository should be reported as old packages by Errata Tool.

[Bug 729231](https://bugzilla.redhat.com/show_bug.cgi?id=729231) is a
long-standing bug discussing problems related to missing released packages in
Errata Tool. The specific fixes described above and shipping in this
release are tracked in [Bug
1152798](https://bugzilla.redhat.com/show_bug.cgi?id=1152798).
