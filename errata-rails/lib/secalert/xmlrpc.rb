module Secalert
  class Xmlrpc
    def self.send_to_secalert(name, logger = Rails.logger)
      logger.info "#{name} to #{Push.oval_conf.xmlrpc_url}:#{Push.oval_conf.xmlrpc_port}"
      rpc = DummyRpc.new(name, logger) unless Push.oval_conf.xmlrpc_enabled
      rpc ||= XMLRPC::Client.new3(:host => Push.oval_conf.xmlrpc_url, :port => Push.oval_conf.xmlrpc_port)
      yield rpc
      logger.info "#{name} RPC Done"
    rescue Exception => e
      logger.warn "Error sending #{name} to secalert: #{e.class} #{e.message}"
    end
  end
end
