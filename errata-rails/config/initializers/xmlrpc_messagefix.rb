# Override XMLRPC::FaultException to_s method
# for consistency and usefullness
#
# In Ruby 1.8, FaultException aliases message to faultString,
# but not to_s. It therefore falls back to StandardError.to_s,
# which is just the class name
#
# Ruby > 1.9 passes faultString to super, so it gets sent by to_s
# An older version of this override set to_s => message, but in
# Ruby > 1.9 message gets set to to_s, which would cause infintie
# recursion.
#
# Have to_s return both fault code and faultstring for consistency
# across Ruby and maximum information
module XMLRPC
  class FaultException < StandardError
    def to_s
      "#{@faultCode}: #{@faultString}"
    end
  end
end
require 'xmlrpc/marshal'

silence_warnings do
  XMLRPC::Config.const_set("ENABLE_NIL_CREATE", true)
  XMLRPC::Config.const_set("ENABLE_NIL_PARSER", true)
end
