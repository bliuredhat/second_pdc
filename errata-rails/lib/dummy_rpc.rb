class DummyRpc

  def initialize(name, logger = ActiveRecord::Base.logger)
    @rpc_name = name
    @logger = logger
  end

  def call(name, *args)
    @logger.info "Dummy RPC call #{@rpc_name} for method #{name} with #{args.size} arguments"
    if args.size > 0
      @logger.info "Arguments are: "
      args.each do |a|
        s = StringIO.new
        PP.pp(a,s)
        s.rewind
        @logger.info s.read
      end
    end
  end

  def method_missing(name, *args)
    call(name,args)
  end

end
