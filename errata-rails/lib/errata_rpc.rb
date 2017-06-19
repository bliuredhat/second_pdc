require 'xmlrpc/client'

class ErrataRpc
  attr_reader :errata, :tps, :rpmdiff, :secure, :wtf
  attr_accessor :port
  def initialize(host = 'errata-xmlrpc.devel.redhat.com', port = 80)
    @host = host
    @port = port
    @use_ssl = (port == 443)
    @clients = { }
    @errata = get_proxy('/errata/errata_service')
    @tps = get_proxy('/tps/tps_service')
    @rpmdiff = get_proxy('/rpmdiff/rpmdiff_service')
    @secure = get_proxy('/errata/secure_service')
    @wtf = get_proxy('/wtf/wtf_service')
  end

  def client(service)
    @clients[service]
  end
  def self.devtest
    rpc = ErrataRpc.new('localhost', 3000)
    return rpc
  end
  
  def self.staging
    ErrataRpc.new('errata-stage.app.eng.bos.redhat.com')
  end

  def self.dev_staging
    ErrataRpc.new('errata-devel.app.eng.bos.redhat.com')
  end

  def self.secure_service
    ErrataRpc.new('errata.devel.redhat.com', 443)
  end

  private
  def get_proxy(service)
    @clients[service] ||= XMLRPC::Client.new3(:host => @host,
                                              :port => @port,
                                              :path => service,
                                              :use_ssl => @use_ssl,
                                              :timeout => 240)
    @clients[service].proxy
  end
end
