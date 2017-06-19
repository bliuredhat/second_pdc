require 'active_support/configurable'
module Push
  class OvalConf
    include ActiveSupport::Configurable
    config.file_path = 'public/ovalcache'
    config.public_url = "http://#{ErrataSystem::SERVICE_NAME}/ovalcache/"

    # Staging instance of errata-srt
    config.xmlrpc_url = 'jenkins.prodsec.redhat.com'
    config.xmlrpc_port = 8888

    if Rails.env.production?
      config.xmlrpc_url = 'errata-srt.app.eng.bos.redhat.com'
      config.xmlrpc_port = 8080
    end

    # Only enabled in production and on ET staging server
    # TODO: Use an ansible var for this
    config.xmlrpc_enabled = Rails.env.production? ||
      ErrataSystem::SERVICE_NAME == 'errata-web-01.host.stage.eng.bos.redhat.com'

    config.freeze
  end
  def self.oval_conf
    OvalConf.config
  end
end
