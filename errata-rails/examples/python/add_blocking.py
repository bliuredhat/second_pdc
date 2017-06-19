#!/usr/bin/python
import requests
import kerberos

class KerbRequest:
    def __init__(self, host):
        self.host = host
        self.hooks=dict(pre_request=self.__kerb_auth)

    def __kerb_auth(self,request):
        service = "HTTP@" + self.host
        try:
            rc, vc = kerberos.authGSSClientInit(service);
        except kerberos.GSSError, e:
            raise kerberos.GSSError(e)
        
        try:
            kerberos.authGSSClientStep(vc, "");
        except kerberos.GSSError, e:
            raise kerberos.GSSError(e)
        request.headers['Authorization'] = "negotiate %s" % kerberos.authGSSClientResponse(vc)

    def __url_for(self, service):
        return 'https://' + self.host + service

    def post(self, service, params):
        return requests.post(self.__url_for(service), data=params, hooks=self.hooks)


rpc = KerbRequest('errata-devel.app.eng.bos.redhat.com')
# Make advisory 12351 depend on 12356
params = {'editorId': '12351_', 'value': '12356'}
res = rpc.post('/errata/add_blocking_advisory', params)
print res.status_code
# Inscrutable javascript
print res.content
