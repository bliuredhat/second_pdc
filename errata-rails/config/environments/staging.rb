ErrataSystem::Application.configure do
  config.cache_classes = true
  config.log_level = :warn
  config.logger.level = Logger::DEBUG
  config.consider_all_requests_local = false
  config.action_controller.perform_caching             = true
  config.action_mailer.delivery_method = :file
  config.serve_static_assets = false

  # Don't want to hard-code the host since we run this on errata-devel and errata-stage
  # SYSTEM_HOSTNAME is defined in config/application.rb
  config.action_controller.asset_host = "https://#{ErrataSystem::SYSTEM_HOSTNAME}/assets"

  config.active_support.deprecation = :notify
end
