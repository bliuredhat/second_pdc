class SecureXmlrpcController < ApplicationController
  include XmlrpcHandling
  def secure_service
    xmlrpc_call(SecureService.new)
  end
end
