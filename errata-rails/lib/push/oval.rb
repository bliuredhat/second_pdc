module Push
  class Oval
    include Optional
    def self.push_oval_to_secalert(errata, logger = Rails.logger)
      return unless errata.supports_oval?
      logger.info "Pushing #{errata.fulladvisory} oval to secalert"
      viewer = TextRender::OvalRenderer.new(errata)
      oval = viewer.get_text
      filename = oval_filename errata
      open(Rails.root.join(Push.oval_conf.file_path, filename), 'w') do |f|
        f.puts oval
      end
      FileUtils.touch Rails.root.join(Push.oval_conf.file_path, '.needindexupdate')
      logger.info "OVAL pushed to secalert"
      send_to_rpc(filename, oval, logger)
      send_published_message(errata, filename)
    end

    def self.oval_filename(errata)
      filename = ['com.redhat.', errata.errata_type.downcase, "-#{errata.oval_errata_id}.xml"].join
    end

    def self.send_to_rpc(filename, oval, logger = Rails.logger)
      begin
        logger.info "Oval RPC to #{Push.oval_conf.xmlrpc_url}:#{Push.oval_conf.xmlrpc_port}"
        rpc = DummyRpc.new('oval', logger) unless Push.oval_conf.xmlrpc_enabled
        rpc ||= XMLRPC::Client.new3(:host => Push.oval_conf.xmlrpc_url, :port => Push.oval_conf.xmlrpc_port)
        rpc.call('errata.saveoval', filename, oval)
        logger.info "OVAL RPC Done"
      rescue Exception => e
        logger.warn "Error pushing oval: #{e.class} #{e.message}"
      end
    end

    def self.send_published_message(errata, filename)
      msg = {
        'errata_id' => errata.id,
        'filename' => filename,
        'url' => "#{Push.oval_conf.public_url}#{filename}"
      }
      MessageBus.send_message(msg, 'oval.published')
    end
  end
end
