module Push
  class PubClient
    def self.get_connection(logger = Rails.logger)
      return DummyClient.new if Rails.env.development? || Rails.env.test?
      return PubClient.new(logger)
    end
    class PubReturnValueError < StandardError
    end

    def initialize(logger = Rails.logger)
      @server = XMLRPC::Client.new(::Pub::SERVER, ::Pub::XMLRPC_URL)
      @logger = logger
      @client_proxy = @server.proxy_async('client')
      @errata_proxy = @server.proxy_async('errata')
      @auth_proxy = @server.proxy_async('auth')
    end

    # Returns the capabilities of the connected pub server.
    #
    # This is an implementation-defined array of strings, advertising which
    # features are supported by this server.
    def capabilities
      @capabilities ||= begin
        perform_call do
          @errata_proxy.capabilities
        end
      rescue XMLRPC::FaultException => e
        if e.message =~ /method.*is not supported/
          # This version of pub is too old to have capabilities API at all.
          # Assume no capabilities
          @logger.warn "Assuming no pub capabilities: #{e.inspect.truncate(300)}"
          []
        else
          # Something else went wrong
          raise
        end
      end
    end

    # Returns true if the connected pub server supports multipush (pushing
    # multiple errata in a single task).
    def supports_multipush?
      capabilities.include?('multipush')
    end

    def fix_cve_names(errata, pub_target, pushed_by)
      raise "Cannot fix cve names for an unpushed advisory." unless errata.status == State::SHIPPED_LIVE
      perform_call do
        @errata_proxy.fix_cves(pub_target, errata.advisory_name, errata.all_cves, pushed_by.login_name)
      end
    end
    # returns: array of hashes (one hash for each task id found)
    def get_tasks(pub_task_ids)
      perform_call do
        @logger.debug "Asking pub for task ids: #{pub_task_ids.inspect}"
        res = @client_proxy.get_tasks(pub_task_ids)
        @logger.debug "Response from pub: #{res.inspect}"
        check_get_tasks_struct(res)
        res
      end
    end

    # returns: task_id
    def submit_push_job(push_job)
      perform_call do
        # options: additional push options: shadow=False, nochannel=False, push_files=True, push_metadata=False
        @logger.debug "Calling pub push_advisory with arguments: #{push_job.target}, \
      #{push_job.errata_pub_name.inspect}, #{push_job.push_user_name.inspect}, \
      #{push_job.pub_options.inspect}"
        
        res = @errata_proxy.push_advisory(push_job.target,
                                          push_job.errata_pub_name,
                                          push_job.push_user_name,
                                          push_job.pub_options)
        @logger.debug "Response from pub: #{res.inspect}"
        res
      end
    end

    # Submits multiple push jobs into a single pub task.
    #
    # Only certain pub targets support this. It's the caller's responsibility to
    # invoke this for the correct targets.
    #
    # Returns the task id.
    def submit_multipush_jobs(push_jobs)
      # Multipush requires that most things are the same between all jobs.
      # Note options are a little different due to handling of priority.
      target         = check_multipush_equal push_jobs, :target
      push_user_name = check_multipush_equal push_jobs, :push_user_name
      pub_options    = check_multipush_pub_options push_jobs

      advisory_names = push_jobs.map(&:errata_pub_name)

      args = [target, advisory_names, push_user_name, pub_options]

      perform_call do
        @logger.debug "Calling pub push_advisory with arguments: #{args.inspect}"
        res = @errata_proxy.push_advisory(*args)
        @logger.debug "Response from pub: #{res.inspect}"
        res
      end
    end

    def cancel_task(id)
      perform_call do
        @logger.debug "Requesting cancel of task #{id}"
        res = @client_proxy.cancel_task(id)
        @logger.debug "Response from pub: #{res.inspect}"    
        res
      end
    end


    private
    
    def login
      auth_res = @auth_proxy.login_password(::Pub::USER, ::Pub::PASSWORD)
      @logger.debug "done."
      unless auth_res
        msg =  "No response from pub login. Could not login to pub xmlrpc interface. Cannot continue"
        @logger.error msg
        raise msg
      end      
    end

    def logout
      @logger.debug "Calling pub logout..."
      auth_res = @auth_proxy.logout()
      @logger.debug "done."
      auth_res
    end

    def check_get_tasks_struct(pub_tasks)
      unless pub_tasks.is_a? Array
        raise PubReturnValueError, "Pub did not return an array. Returned instead: #{pub_tasks.inspect}"
      end

      pub_tasks.each { |pub_task|
        unless pub_task.is_a? Hash
          raise PubReturnValueError, "Pub task struct is not a Hash. Instead it is: #{pub_task.inspect}"
        end
        
        unless ['id', 'is_finished', 'is_failed'].all? { |key| pub_task.keys.include? key }
          raise PubReturnValueError, "Pub hash for task doesn't contain all the required keys: 'id', 'is_finished', 'is_failed'."
        end
      }
    end

    def check_multipush_equal(push_jobs, attribute, values = nil)
      values ||= push_jobs.map(&attribute)
      values.uniq!
      if values.length > 1
        raise "Cannot use multipush!\n#{attribute} mismatch on submitted jobs: #{values.inspect.truncate(60)}"
      end
      values.first
    end

    # Check pub option validity for multipush and return the options which should be used.
    #
    # Slightly different from check_multipush_equal because it has to handle jobs having
    # different priorities.
    def check_multipush_pub_options(push_jobs)
      options_excluding_priority = push_jobs.map do |pj|
        pj.pub_options.except('priority')
      end

      # With the exception of 'priority', other options should all be equal
      out = check_multipush_equal push_jobs, :pub_options, options_excluding_priority

      # The priority we'll actually use should be the highest out of the jobs
      priority = push_jobs.map{ |pj| pj.pub_options['priority'] }.max

      out.merge('priority' => priority)
    end

    def perform_call(&block)
      login
      begin
        res = yield
      ensure
        logout rescue nil
      end
      res
    end

  end
end
