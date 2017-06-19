require 'rubygems'
require 'daemons'
require 'optparse'

module MessageBus
  class Command

    def initialize(options = {})
      @files_to_reopen = []
      @handler_class = options[:handler_class] || 'MessageBus::QpidHandler'
      @app_name = options[:app_name] || 'qpid_service'
    end

    def daemonize
      ObjectSpace.each_object(File) do |file|
        @files_to_reopen << file unless file.closed?
      end

      Daemons.run_proc(@app_name, :monitor => true, :dir => "#{Rails.root}/tmp/pids", :dir_mode => :normal, :backtrace => true, :log_output => true) do
        run
      end
    end

    # 'Daemons' gem makes some particular changes such as closing
    # all file descriptors when it demonizes the process.
    # So below we change the dir back to Rails.root and reopen
    # all the file descriptors.
    # Please refer to http://daemons.rubyforge.org/Daemons.html
    def run
      Dir.chdir(Rails.root)

      # Re-open file handles
      @files_to_reopen.each do |file|
        begin
          file.reopen file.path, 'a+'
          file.sync = true
        rescue ::Exception
        end
      end

      ActiveRecord::Base.connection.reconnect!
      handler = @handler_class.constantize.new
      handler.init_subscriptions
      handler.listen

    rescue => e
      MBUSLOG.fatal e
      MBUSLOG.fatal e.backtrace.join("\n")
      STDERR.puts "#{e.message}\n#{e.backtrace.join("\n") if Rails.env.development?}"
      exit 1

    end
  end
end
