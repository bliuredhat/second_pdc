module Push
  class DummyClient
    attr_accessor :should_fail
    attr_accessor :last_submit_values
    def submit_push_job(push_job)
      @last_submit_values = { }
      [:target, :errata_pub_name, :push_user_name, :pub_options].each do |k|
        @last_submit_values[k] = push_job.send(k).clone
      end
      Rails.logger.info @last_submit_values.inspect
      return nil if should_fail

      # when using dummy client in test environment, start from a high
      # ID (should be much higher than any ID already used in
      # fixtures), then simulate autoincrement.
      #
      # Starting with a high ID allows adding new push jobs to
      # fixtures without changing the result of existing tests.
      min_id = Rails.env.test? ? 99999 : 0
      return (PushJob.pluck("GREATEST(#{min_id},MAX(pub_task_id))").first || min_id) + 1
    end

    def submit_multipush_jobs(push_jobs)
      # Since all we need to do is return a new task id...
      submit_push_job(push_jobs.first)
    end

    def supports_multipush?
      # mock this if you want it to be false
      true
    end

    def get_tasks(ids)
      res = []
      ids.each do |i|
        res << { 'id' => i, 'is_finished' => false, 'is_failed' => false}
      end
      res
    end
  end
end
