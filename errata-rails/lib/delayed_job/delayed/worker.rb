module Delayed
  class Worker
    @@sleep_delay = 5
    
    cattr_accessor :sleep_delay

    cattr_accessor :logger
    self.logger = if defined?(Merb::Logger)
      Merb.logger
    elsif defined?(RAILS_DEFAULT_LOGGER)
      RAILS_DEFAULT_LOGGER
    end

    def initialize(options={})
      @quiet = options[:quiet]
      Delayed::Job.min_priority = options[:min_priority] if options.has_key?(:min_priority)
      Delayed::Job.max_priority = options[:max_priority] if options.has_key?(:max_priority)
    end

    def start
      say "*** Starting job worker #{Delayed::Job.worker_name}"

      trap('TERM') do
        Thread.new { say 'Exiting...' }
        $exit = true
      end

      trap('INT')  do
        Thread.new { say 'Exiting...' }
        $exit = true
      end

      loop do
        result = nil

        realtime = Benchmark.realtime do
          result = Delayed::Job.work_off
        end

        count = result.sum

        break if $exit

        if count.zero?
          sleep(@@sleep_delay)
        else
          say "#{count} jobs processed at %.4f j/s, %d failed ..." % [count / realtime, result.last]
        end

        break if $exit
      end

    ensure
      Delayed::Job.clear_locks!
    end

    def say(text)
      puts text unless @quiet
      logger.info text if logger
    end

    # Upstream commit 855f1ba Added #before_fork and #after_fork on the backends that is called
    # before and after forking the background process
    def self.before_fork
      ActiveRecord::Base.clear_all_connections!
    end

    def self.after_fork
      ActiveRecord::Base.establish_connection
    end
  end
end
