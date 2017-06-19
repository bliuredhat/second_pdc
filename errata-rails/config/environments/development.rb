ErrataSystem::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false
  config.logger.level = Logger::DEBUG
  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports
  config.consider_all_requests_local       = true

  # Want to use some fragment caching
  config.action_controller.perform_caching = true

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log
  config.action_mailer.delivery_method = :file
  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  # Disable ssl in development
  SslRequirement.disable_ssl_check = true

  # Using PushJob.descendants, which does not automatically work
  # in development due to config.cache_classes = false
  config.after_initialize do
    [
      AltsrcPushJob,
      CdnPushJob,
      CdnStagePushJob,
      FtpPushJob,
      RhnLivePushJob,
      RhnStagePushJob,
    ]
  end
end

