require 'rubygems'
require 'daemons'
require 'optparse'

module Delayed
  class Command
    attr_accessor :worker_count
    
    def initialize(args)
      @files_to_reopen = []
      @options = {:quiet => true}
      
      @worker_count = 1
      
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] start|stop|restart|run"

        opts.on('-h', '--help', 'Show this message') do
          puts opts
          exit 1
        end
        opts.on('-e', '--environment=NAME', 'Specifies the environment to run this delayed jobs under (test/development/production).') do |e|
          STDERR.puts "The -e/--environment option has been deprecated and has no effect. Use RAILS_ENV and see http://github.com/collectiveidea/delayed_job/issues/#issue/7"
        end
        opts.on('--min-priority N', 'Minimum priority of jobs to run.') do |n|
          @options[:min_priority] = n
        end
        opts.on('--max-priority N', 'Maximum priority of jobs to run.') do |n|
          @options[:max_priority] = n
        end
        opts.on('-n', '--number_of_workers=workers', "Number of unique workers to spawn") do |worker_count|
          @worker_count = worker_count.to_i rescue 1
        end
      end
      @args = opts.parse!(args)
      Delayed::Worker.logger = ErrataLogger.new('worker')
    end
  
    def daemonize
      Delayed::Worker.before_fork
      ObjectSpace.each_object(File) do |file|
        @files_to_reopen << file unless file.closed?
      end
      
      worker_count.times do |worker_index|
        process_name = worker_count == 1 ? "delayed_job" : "delayed_job.#{worker_index}"
        Daemons.run_proc(process_name, :monitor => true, :dir => "#{Rails.root}/tmp/pids", :dir_mode => :normal, :ARGV => @args) do |*args|
          run process_name
        end
      end
    end

    # 'Daemons' gem makes some particular changes such as closing
    # all file descriptors when it demonizes the process.
    # So below we change the dir back to Rails.root and reopen
    # all the file descriptors.
    # Please refer to http://daemons.rubyforge.org/Daemons.html
    def run(worker_name = nil)
      Dir.chdir(Rails.root)

      # Re-open file handles
      @files_to_reopen.each do |file|
        begin
          file.reopen file.path, 'a+'
          file.sync = true
        rescue ::Exception
        end
      end

      Delayed::Worker.after_fork

      Delayed::Job.worker_name = "#{worker_name} #{Delayed::Job.worker_name}"

      Delayed::Worker.new(@options).start
    rescue => e
      Delayed::Worker.logger.fatal e
      Delayed::Worker.logger.fatal e.backtrace.join("\n")
      STDERR.puts e.message
      exit 1
    end
    
  end
end
