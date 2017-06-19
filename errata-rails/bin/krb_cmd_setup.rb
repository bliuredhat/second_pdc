require 'rubygems'
require 'bundler/setup'

module KrbCmdSetup
  if (pwd = Dir.pwd) =~ /bin$/
    root = File.expand_path('../', pwd)
    puts "INFO: changing PWD to #{root}"
    Dir.chdir root
  end

  unless ENV['RAILS_ENV']
    if '/var/www/errata_rails' == Dir.pwd
      env_dir = "#{Dir.pwd}/config/environments"
      env   = 'production' if File.exist?("#{env_dir}/production.rb")
      env ||= 'staging'    if File.exist?("#{env_dir}/staging.rb")
    end
    env ||= 'development'
    ENV['RAILS_ENV'] = env
  end

  puts "Loading rails environment #{ENV['RAILS_ENV']}"
  ENV['LOGFILE_PREFIX'] = File.basename $0, '.*'

  require File.expand_path('./config/application')
  Rails.application.require_environment!
  require 'krb_auth'

  def get_user(*roles)
    if Rails.env.development?
      user = User.fake_devel_user
    else
      user = KrbAuth.get_user
    end
    raise "Could not authenticate login" unless user

    return user if roles.empty?

    unless user.in_role?(*roles)
      raise "You do not have permissions to perform this function"
    end
    return user
  end

  def in_production?
    Rails.env.production?
  end
end
