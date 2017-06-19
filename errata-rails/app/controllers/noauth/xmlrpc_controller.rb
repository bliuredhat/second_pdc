class Noauth::XmlrpcController < Noauth::ControllerBase
  include XmlrpcHandling
  def errata_service
    xmlrpc_call(ErrataService.new)
  end

  def tps_service
    xmlrpc_call(TpsService.new)
  end
end
