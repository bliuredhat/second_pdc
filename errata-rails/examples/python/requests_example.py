#!/usr/bin/python

import requests
from requests_kerberos import HTTPKerberosAuth
from sys import argv

ABIDIFF_RELEASES = [
    'RHEL-6.6.0',
    'FAST6.6',
]

# Install the Red Hat CA cert like this if you don't have it already:
#
#   cd /etc/pki/tls/certs
#   curl --insecure -o redhat-cacert.crt http://password.corp.redhat.com/cacert.crt
#   echo '59aa5919eccaf4cbf77dbc9ede454a65a9116d85d35447af0c2de2f62123042e redhat-cacert.crt' | sha256sum --check
#   ln -s redhat-cacert.crt `openssl x509 -hash -noout -in redhat-cacert.crt`.0
#   cat redhat-cacert.crt >> ca-bundle.crt
#
# Source: https://mojo.redhat.com/docs/DOC-926093
#
# (Or you can set verify=False below to skip the cert verification).
#
CA_CERTS = '/etc/pki/tls/certs/ca-bundle.crt'

BASE_URL = 'https://errata.devel.redhat.com/'
ERRATA_URL = BASE_URL + '/advisory/{0}.json'

def get_errata_info(errata_id):
    return requests.get(ERRATA_URL.format(errata_id), auth=HTTPKerberosAuth(), verify=CA_CERTS).json()

def release_name(errata_info):
    return errata_info['release']['name']

def errata_name(errata_info):
    return errata_info['advisory_name']

def abidiff_required(errata_info):
    return release_name(errata_info) in ABIDIFF_RELEASES

errata_id = argv[1]
errata_info = get_errata_info(errata_id)

print "Errata: {0}".format(errata_name(errata_info))
print "Release: {0}".format(release_name(errata_info))
print "ABIDiff: {0}".format(abidiff_required(errata_info))
