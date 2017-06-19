Fix skipping SSL certificate validation for testing instances of Bugzilla

Our QE team often instantiates testing instances of the various release
tool-chain services. When a test instance of Bugzilla is created it doesn't
have a proper trusted certificate, so to connect to it Errata Tool needs to
skip the usual SSL certificate verification.

After the recent upgrade to Ruby 2.2, changes to the default OpenSSH defaults
meant that the certificate verification was not being properly skipped and
test Errata Tool instances were unable to connect to their test Bugzilla
instances. This has been fixed.

(Thanks to [Yuxiang Zhu](mailto:yuxzhu@redhat.com) for contributing this
patch.)
