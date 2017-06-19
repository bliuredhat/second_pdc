# Manages the lifecycle of Delayed::Jobs being
# tracked by a JobTracker.
# Also clears the attempts counter on job success

class DelayedJobObserver < ActiveRecord::Observer
  observe Delayed::Job

  # Ensure all jobs created during the transaction are added
  # to the tracker, if it exists
  def after_create(job)
    if tracker = Thread.current[:job_tracker]
      tracker.delayed_jobs << job
      tracker.update_attributes!(:total_job_count => tracker.total_job_count + 1)
    end
  end

  # Notify a tracker via the mapping that the job has failed
  def after_update(obj)
    return if obj.last_error.nil?
    map = JobTrackerDelayedMap.find_by_delayed_job_id obj
    return if map.nil?
    map.job_tracker.job_failed(obj)
  end

  # Eliminate any mappings before job is deleted
  def before_destroy(job)
    JobTrackerDelayedMap.where(:delayed_job_id => job).destroy_all
  end

  def before_update(job)
    reset_attempts(job)
  end

  private

  def reset_attempts(job)
    if job.last_error.nil? && job.locked_at.nil? &&
       job.locked_by.nil? && job.attempts > 0
      job.attempts = 0
    end
  end
end
