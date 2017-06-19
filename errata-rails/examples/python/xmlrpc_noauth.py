#!/usr/bin/python
#
# Usage:
#  ./xmlrpc_noauth.py <errata_id>
#
#
import sys
import xmlrpclib
import pprint as pp
import re

# Specify an errata id on the command line
errata_id = sys.argv[1]

# Second arg to filter the method names
method_match = ''
if len(sys.argv) > 2:
    method_match = sys.argv[2]

et_host = 'errata-web-03.host.qe.eng.pek2.redhat.com'
#et_host = 'errata-web-01.host.stage.eng.bos.redhat.com'
#et_host = 'errata.devel.redhat.com'

et_xmlrpc = xmlrpclib.ServerProxy('http://%s/errata/xmlrpc.cgi' % et_host)

# Uncomment the methods you are interested in
# See also other methods here:
#   https://errata.devel.redhat.com/rdoc/ErrataService.html
xmlrpc_methods = [
    'get_advisory_rhn_metadata',
    'get_advisory_rhn_file_list',
    #'get_advisory_rhn_nonrpm_file_list',
    'get_advisory_cdn_metadata',
    'get_advisory_cdn_file_list',
    #'get_advisory_cdn_nonrpm_file_list',
    #'get_advisory_cdn_docker_file_list',
]

for xmlrpc_method in xmlrpc_methods:
    if not re.search(method_match, xmlrpc_method):
        continue
    print "---------------------------------------------"
    print "Calling %s(%s)" % (xmlrpc_method, errata_id)
    print "---------------------------------------------"
    response = getattr(et_xmlrpc, xmlrpc_method)(errata_id)
    pp.pprint(response)
