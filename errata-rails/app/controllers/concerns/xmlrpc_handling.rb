module XmlrpcHandling
  require 'xmlrpc/marshal'
  extend ActiveSupport::Concern
  include CleanBacktrace

  included do
    verify :method => :post
  end

  protected
  def remote_address
    addr = request.env['HTTP_X_FORWARDED_FOR']
    addr ||= request.env['REMOTE_ADDR']
  end

  def remote_host
    begin
      return Resolv::DNS.new.getname(remote_address).to_s
    rescue => e
      return remote_address
    end
  end

  def xmlrpc_call(srv)
    method_name, params = XMLRPC::Marshal.load_call(request.raw_post)
    response.content_type = 'text/xml'
    if 'system_info' == method_name
      render :xml =>
        XMLRPC::Marshal.dump_response("Errata system version #{SystemVersion::VERSION}"),
      :status => :ok
      return
    end

    xmlrpc_call_log srv.class, method_name
    unless srv.respond_to?(method_name)
      RPCLOG.warn "Unknownn method call #{method_name}"
      render :xml => xmlrpc_fault("Unknown method name #{method_name}"), :status => :ok
      return
    end

    if srv.class.respond_to?(:need_remote_host)
      params << remote_host if srv.class.need_remote_host(method_name)
    end

    begin
      res = srv.send(method_name, *params)
      res = false if res.nil?
      render :xml => XMLRPC::Marshal.dump_response(res), :status => :ok
    rescue => e
      RPCLOG.error e
      RPCLOG.error clean_backtrace(e).join("\n")
      render :xml => xmlrpc_fault(e.message), :status => :ok
    end
  end

  def xmlrpc_call_log(service_name, method_name)
    RPCLOG.info "#{service_name}.#{method_name} call from #{remote_host}"
  end

  def xmlrpc_fault(msg)
    XMLRPC::Marshal.dump_response(XMLRPC::FaultException.new(2, msg))
  end
end
