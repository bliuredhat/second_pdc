namespace :debug do
  namespace :delayed_job do
    #
    # For testing the delayed job exception hack
    # in config/initializers/delayed_job_exception_notifier
    #
    # Note that it won't actually send an email
    # for real unless you set
    #  config.action_mailer.delivery_method = :smtp
    # in config/environments/development
    #
    # Example usage:
    #  $ rake jobs:clear # (optional)
    #  $ rake debug:delayed_job:add_exception_job
    #  $ rake jobs:work
    #  (press Ctrl-C)
    #  $ rake jobs:clear # (optional)
    #

    # These classes will be visible only if you run delayed job
    # using rake jobs:work.
    class ExceptionJobPayload
      def perform
        raise 'boom!'
      end
    end

    desc "Enqueue a delayed job that will raise an exception"
    task :add_exception_job => [:environment, :development_only] do
      Delayed::Job.enqueue(ExceptionJobPayload.new)
    end

    class TimeoutJobPayload
      def perform
        # 180 seconds. Should timeout after 120 seconds.
        # See config/initializers/delayed_job_config
        18.times { |i| sleep(10) and puts "Zzzz... #{(i+1)*10}" }
        raise 'more than three minutes' # hopefully it won't get here...
      end
    end

    desc "Enqueue a delayed job that will timeout"
    task :add_timeout_job =>  [:environment, :development_only] do
      Delayed::Job.enqueue(TimeoutJobPayload.new)
    end

  end
end
