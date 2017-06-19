#!/usr/bin/python
import httplib
import xmlrpclib
import kerberos

# Stolen from FreeIPA source freeipa-1.2.1/ipa-python/krbtransport.py
class KerbTransport(xmlrpclib.SafeTransport):
    """Handles Kerberos Negotiation authentication to an XML-RPC server."""

    def get_host_info(self, host):

        host, extra_headers, x509 = xmlrpclib.Transport.get_host_info(self, host)

        # Set the remote host principal
        h = host
        hostinfo = h.split(':')
        service = "HTTP@" + hostinfo[0]

        try:
            rc, vc = kerberos.authGSSClientInit(service);
        except kerberos.GSSError, e:
            raise kerberos.GSSError(e)

        try:
            kerberos.authGSSClientStep(vc, "");
        except kerberos.GSSError, e:
            raise kerberos.GSSError(e)

        extra_headers = [
            ("Authorization", "negotiate %s" % kerberos.authGSSClientResponse(vc) )
            ]

        return host, extra_headers, x509



if __name__ == "__main__":
    
    server = xmlrpclib.Server('https://errata.devel.redhat.com/errata/secure_service', transport = KerbTransport())
    print server.echo_user()
