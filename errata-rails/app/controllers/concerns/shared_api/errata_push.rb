module SharedApi::ErrataPush
  def create_push_jobs(push_request)
    ActiveRecord::Base.transaction do
      results = push_request.targets.map do |t|
        result = begin
          create_push_job(t, push_request)
        rescue StandardError => ex
          ex
        end
        [t.name, result]
      end

      with_error = results.select{|x| x.second.kind_of?(Exception)}
      if with_error.any?
        raise DetailedArgumentError.merge_errors(with_error)
      end

      results.map(&:second)
    end
  end

  def create_push_job(target, push_request)
    name = target.name.to_s
    policy = push_request.policy_for_target(target)
    errata = push_request.errata

    if name.blank?
      raise DetailedArgumentError, 'push target' => 'name was not provided'
    end

    if policy.nil?
      raise DetailedArgumentError, name => "is currently not an applicable push target for #{errata.advisory_name}"
    end

    pub_options = target.pub_options
    if !policy.push_possible?(pub_options)
      raise DetailedArgumentError, policy.errors
    end

    job = policy.create_new_push_job(User.current_user)

    # for pre/post push tasks and pub options, start out with the defaults.
    # Any provided tasks/options override, rather than append to, the defaults.
    job.set_defaults

    if (x = target.pre_push_tasks)
      job.pre_push_tasks = x.dup
    end

    if (x = target.post_push_tasks)
      job.post_push_tasks = x.dup
    end

    if pub_options
      job.pub_options = pub_options.dup
    end

    if (x = target.exclude_pre_tasks)
      job.pre_push_tasks -= x
    end

    if (x = target.append_pre_tasks)
      if (common = (target.exclude_pre_tasks || []) & x).any?
        raise DetailedArgumentError, :exclude_pre_tasks => "has tasks also specified in append_pre_tasks: #{common.sort.join(', ')}"
      end
      job.pre_push_tasks += target.append_pre_tasks
    end

    if (x = target.exclude_post_tasks)
      job.post_push_tasks -= x
    end

    if (x = target.append_post_tasks)
      if (common = (target.exclude_post_tasks || []) & x).any?
        raise DetailedArgumentError, :exclude_post_tasks => "has tasks also specified in append_post_tasks: #{common.sort.join(', ')}"
      end
      job.post_push_tasks += x
    end

    if (x = target.exclude_options)
      job.pub_options.reject! {|k,v| k.in? x}
    end

    if (x = target.append_options)
      # append_options can be hash or array, where an array is
      # interpreted as keys of a hash where all values are true
      append_options = PushRequest::Target.options_as_hash(x)
      if (common = (target.exclude_options || []) & append_options.keys).any?
        raise DetailedArgumentError, :exclude_options => "has options also specified in append_options: #{common.sort.join(', ')}"
      end
      job.pub_options.merge! append_options
    end

    job.save!

    # may have changed some attributes
    errata.reload

    job
  end
end
