#!/usr/bin/env ruby
require 'rubygems'
require 'daemons'
require 'getoptlong'

def usage(msg = nil)
  $stderr.puts("Error: #{msg}\n") if msg
  $stderr.puts <<"eos"
Usage: messaging_daemon.rb [options] -- [daemon options]

Options:

  --use-qpid        Connect to the older QPID-based messaging system (default)
  --use-messagebus  Connect to the newer messaging system.
eos

  exit 3
end

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--use-qpid', GetoptLong::NO_ARGUMENT ],
  [ '--use-messagebus', GetoptLong::NO_ARGUMENT ]
)

qpid = false
messagebus = false
opts.each do |opt,arg|
  case opt
    when '--help'
      usage()
    when '--use-qpid'
      qpid = true
    when '--use-messagebus'
      messagebus = true
  end
end

if qpid && messagebus
  usage('must provide only one of --use-qpid or --use-messagebus')
end

if !qpid && !messagebus
  qpid = true
end

approot = File.expand_path(File.join(File.dirname(__FILE__), '..'))
unless ENV['RAILS_ENV']
  if '/var/www/errata_rails' == approot
    env = 'production' if File.exists?("#{approot}/config/environments/production.rb")
    env ||= 'staging' if File.exists?("#{approot}/config/environments/staging.rb")
  end
  env ||= 'development'
  ENV['RAILS_ENV'] = env
end
puts "Loading rails environment #{ENV['RAILS_ENV']}"
ENV['LOGFILE_PREFIX'] = messagebus ? 'messaging_service' : 'qpid_service'
require File.join(approot, 'config', 'environment')
require 'message_bus/command'

puts "Using #{messagebus ? 'message bus' : 'qpid'}"

options = if messagebus
  {
    :handler_class => 'MessageBus::Handler',
    :app_name => 'messaging_service',
  }
else
  {}
end

MessageBus::Command.new(options).daemonize
