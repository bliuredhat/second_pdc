require File.expand_path('../boot', __FILE__)

# Do this so our log files are group writable
File.umask(0002)

# Do this so we use the default kerb ticket cache instead of apache's
ENV.delete('KRB5CCNAME')

require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module ErrataSystem

  # Need to know the hostname in environments/staging.rb.
  # (Not sure if there is a better way to do it..)
  # TODO: Consider using ansible vars for these
  SYSTEM_HOSTNAME = %x{/bin/hostname}.strip

  SERVICE_NAME = case SYSTEM_HOSTNAME
  when 'errata-web-01.host.prod.eng.bos.redhat.com'
    # Special case for production since it's known by its cname
    'errata.devel.redhat.com'
  else
    SYSTEM_HOSTNAME
  end

  class Application < Rails::Application

    # Will show these in the layout footer
    DB_HOST = config.database_configuration[Rails.env]['host']
    DB_NAME = config.database_configuration[Rails.env]['database']

    # Need to explicitly require this because autoloading is not enabled yet
    require "#{config.root}/lib/errata_logger"

    config.logger = ErrataLogger.new(Rails.env)
    config.logger.level = Logger::INFO
    config.log_tags = [:uuid]
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.autoload_paths += %W(exhibits observers models/concerns controllers/concerns models/comments models/state_transition_guards).map {|v| "#{config.root}/app/#{v}"}

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    config.plugins = []

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer
    config.active_record.observers = \
      :bug_observer,
      :build_cc_observer,
      :build_comment_observer,
      :build_messaging_observer,
      :channel_repo_link_observer,
      :covscan_create_observer,
      :cpe_observer,
      :delayed_job_observer,
      :errata_audit_observer,
      :prepush_trigger_observer,
      :push_job_observer,
      :rpmdiff_obsoletion_observer,
      :rpmdiff_waiver_observer,
      :rss_observer,
      :state_index_observer,
      :dirty_record_observer,
      :jira_issue_observer,
      :security_approval_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    config.i18n.enforce_available_locales = true

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    config.action_view.field_error_proc = lambda do |*args|
      ApplicationHelper.field_with_errors(*args)
    end

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"
    config.colorize_logging = false
    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]
    config.autoload_paths += %W( #{config.root}/lib )

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      :address    => "smtp.corp.redhat.com",
      :domain => "redhat.com",
      :content_type => "text/plain",
      :enable_starttls_auto => false
    }

    config.action_mailer.default_url_options = case Rails.env
                                               when 'production' then { :host => 'errata.devel.redhat.com', :protocol => 'https' }
                                               when 'staging'    then { :host => SYSTEM_HOSTNAME,           :protocol => 'https' }
                                               when 'test'       then { :host => 'errata-test.example.com', :protocol => 'https' }
                                               else                   { :host => '0.0.0.0',                 :protocol => 'http', :port => 3000 }
                                               end

    unless Rails.env.development?
      notification_email_opts = {
        :email_prefix => "[#{Rails.env} Errata System Error] ",
        :sender_address => %{"Errata System" <erratatool@#{SYSTEM_HOSTNAME}>},
        :exception_recipients => ['errata-owner@redhat.com']
      }

      # Adding this here will override action_mailer.delivery_method from
      # config/environments/staging so we send real exception emails on staging servers.
      notification_email_opts.merge!(
        :delivery_method => :smtp
      ) if Rails.env.staging? && SYSTEM_HOSTNAME.in?(%w[ errata-stage.app.eng.bos.redhat.com
                                                         errata-web-01.host.stage.eng.bos.redhat.com ])

      config.middleware.use(ExceptionNotification::Rack, :email => notification_email_opts)
    end

  end
end
