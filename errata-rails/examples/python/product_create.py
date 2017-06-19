#!/usr/bin/python
import requests
import kerberos
import json

class KerberizedJSON:
    def __init__(self, host):
        self.host = host
        self.headers = {'Accept': 'application/json', 'content-type': 'application/json'}
        self.hooks=dict(response=self.__parse_json, pre_request=self.__kerb_auth)

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


    def __parse_json(self, response):
        response._content = json.loads(response.content)

    def __url_for(self, service):
        return 'https://' + self.host + service

    def get(self, service):
        return requests.get(self.__url_for(service),  headers=self.headers, hooks=self.hooks)

    def post(self, service, data):
        return requests.post(self.__url_for(service), json.dumps(data), headers=self.headers, hooks=self.hooks)

    def put(self, service, data):
        return requests.put(self.__url_for(service), json.dumps(data), headers=self.headers, hooks=self.hooks)


rpc = KerberizedJSON('errata-devel.app.eng.bos.redhat.com')
print rpc.get('/user/show/jorris.json').content
r = rpc.post('/rhel_releases', {'rhel_release': {'name': 'RHEL-5.8.Z', 'description': 'RHEL-5.8.Z'}})
rhel_release =  r.content['rhel_release']
print rhel_release
rhel_id = rhel_release['id']
print rhel_id

r = rpc.post('/products/RHEL/product_versions', {'product_version': 
                                               {'name': 'RHEL-5.8.Z', 
                                                'description': 'RHEL-5.8.Z',
                                                'sig_key_name': 'redhatrelease',
                                                'rhel_release_id': rhel_id}})

product_version = r.content['product_version']
print product_version
product_version_id = product_version['id']
variants = [{'name': '5Server-5.8.Z', 'description': 'Red Hat Enterprise Linux (v. 5 server)'},
            {'name': '5Client-5.8.Z', 'description': 'Red Hat Enterprise Linux Desktop (v. 5 client)'},
            {'name': '5Server-Cluster-5.8.Z', 'description': 'RHEL Clustering (v. 5 server)', 'rhel_variant_name': '5Server-5.8.Z'},
            {'name': '5Server-ClusterStorage-5.8.Z', 'description': 'RHEL Cluster-Storage (v. 5 server)', 'rhel_variant_name': '5Server-5.8.Z'},
            {'name': '5Server-VT-5.8.Z', 'description': 'RHEL Virtualization (v. 5 server)', 'rhel_variant_name': '5Server-5.8.Z'},
            {'name': '5Client-VT-5.8.Z', 'description': 'RHEL Desktop Multi OS (v. 5 client)', 'rhel_variant_name': '5Client-5.8.Z'},
            {'name': '5Client-Workstation-5.8.Z', 'description': 'RHEL Desktop Workstation (v. 5 client)', 'rhel_variant_name': '5Client-5.8.Z'},
            {'name': '5Server-DPAS-5.8.Z', 'description': 'RHEL Optional Productivity Applications (v. 5 server)', 'rhel_variant_name': '5Server-5.8.Z'}]

for v in variants:
    url = "/product_versions/%s/variants" % product_version_id
    res = rpc.post(url, {'variant': v})
    print res.content

channels = [{'arch': 'i386', 'name': 'rhel-i386-server-5', 'variant': '5Server-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ia64', 'name': 'rhel-ia64-server-5', 'variant': '5Server-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ppc', 'name': 'rhel-ppc-server-5', 'variant': '5Server-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 's390x', 'name': 'rhel-s390x-server-5', 'variant': '5Server-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-server-5', 'variant': '5Server-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-server-cluster-5', 'variant': '5Server-Cluster-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ia64', 'name': 'rhel-ia64-server-cluster-5', 'variant': '5Server-Cluster-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ppc', 'name': 'rhel-ppc-server-cluster-5', 'variant': '5Server-Cluster-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-server-cluster-5', 'variant': '5Server-Cluster-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-server-cluster-storage-5', 'variant': '5Server-ClusterStorage-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ia64', 'name': 'rhel-ia64-server-cluster-storage-5', 'variant': '5Server-ClusterStorage-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ppc', 'name': 'rhel-ppc-server-cluster-storage-5', 'variant': '5Server-ClusterStorage-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-server-cluster-storage-5', 'variant': '5Server-ClusterStorage-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-server-vt-5', 'variant': '5Server-VT-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'ia64', 'name': 'rhel-ia64-server-vt-5', 'variant': '5Server-VT-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-server-vt-5', 'variant': '5Server-VT-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-client-5', 'variant': '5Client-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-client-5', 'variant': '5Client-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-client-vt-5', 'variant': '5Client-VT-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-client-vt-5', 'variant': '5Client-VT-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-client-workstation-5', 'variant': '5Client-Workstation-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-client-workstation-5', 'variant': '5Client-Workstation-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'i386', 'name': 'rhel-i386-server-productivity-5', 'variant': '5Server-DPAS-5.8.Z', 'type': 'PrimaryChannel'},
            {'arch': 'x86_64', 'name': 'rhel-x86_64-server-productivity-5', 'variant': '5Server-DPAS-5.8.Z', 'type': 'PrimaryChannel'}]

url = "/product_versions/set_channels/%s" % product_version_id
res = rpc.post(url, {'channels': channels})
print res.content

