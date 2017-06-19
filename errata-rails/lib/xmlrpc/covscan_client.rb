#
# An XMLRPC Client that can connect to Covscan in order to
# request scan tasks, or query for info about existing tasks.
#
# See:
#   https://bugzilla.redhat.com/show_bug.cgi?id=731716
#   https://engineering.redhat.com/trac/CoverityScan/wiki
#   http://etherpad.corp.redhat.com/Covscan-ErrataTool-Integration (temporary)
#   lib/task/debug_covscan_client.rake
#
module XMLRPC
  class CovscanClient < KerberosClient
    def initialize(opts={})
      super(opts.delete(:url) || Settings.covscan_xmlrpc_url, opts.reverse_merge(:namespace=>'errata'))
    end
  end
end
