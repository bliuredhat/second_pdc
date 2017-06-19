module Push
  # This job will scan for and trigger pre-push jobs on any eligible errata.
  # It's intended to be run periodically, but may also be run sooner based on certain
  # events.
  class PrepushTriggerJob
    def perform
      PushErrata.trigger_prepush_for_eligible_errata
    end

    def rerun?
      true
    end

    def next_run_time
      Time.now + Settings.prepush_trigger_interval
    end

    # Schedule this job to run some time soon.
    #
    # Compared to the conventional enqueue_once often used for delayed jobs, if there is
    # already an instance of this job enqueued, this will update its scheduled runtime to
    # some time soon.
    def self.run_soon
      now = Time.now
      payload = new

      if Delayed::Job.enqueue_once(payload, 0, now)
        # job was just created
        return
      end

      # job already exists, make it run soon
      job = Delayed::Job.where(:handler => payload.to_yaml).first!
      job.update_column(:run_at, now)
    end
  end
end
