### Added checksums to get_advisory_cdn/rhn_file_list XMLRPC method

A checksums field has been added to the get_advisory_cdn_file_list and
get_advisory_rhn_file_list XML-RPC methods. It contains SHA256 and MD5
checksums of the RPM packages that an advisory is shipping.
