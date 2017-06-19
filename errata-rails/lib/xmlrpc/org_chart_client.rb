#
# See https://docs.engineering.redhat.com/display/HTD/Organizational+Chart+User+Guide#OrganizationalChartUserGuide-XML-RPCInterfaceV2.0
#
module XMLRPC
  class OrgChartClient < KerberosClient
    def initialize(opts={})
      super(Settings.orgchart_xmlrpc_url, opts.reverse_merge(:namespace=>'OrgChart')) do |curl|
        # The default is "application/x-www-form-urlencoded" but OrgChart doesn't like that
        curl.headers["Content-Type"] = "application/soap+xml"
      end
    end
  end
end
