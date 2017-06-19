module Push
  class RelPrepToPushReadyJob
    def perform
      PushErrata.move_rel_prep_to_push_ready
    end

    def rerun?
      true
    end

    def next_run_time
      Time.now + Settings.rel_prep_to_push_ready_interval
    end

    def self.enqueue_once
      Delayed::Job.enqueue_once self.new
    end
  end
end
