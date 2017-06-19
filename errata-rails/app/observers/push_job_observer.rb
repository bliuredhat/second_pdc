class PushJobObserver < ActiveRecord::Observer
  observe PushJob

  def after_commit(job)
    if post_push_failed?(job)
      Notifier.post_push_failed(job).deliver
    end
    if auto_prepush_failed?(job)
      Notifier.auto_prepush_failed(job).deliver
    end
  end

  private
  def post_push_failed?(job)
    job_changed_to_status?(job, 'POST_PUSH_FAILED')
  end

  # True if this job is an automated prepush which has just failed.
  #
  # In this case, because the job wasn't triggered directly by a user and its failure
  # won't post a comment on the advisory, the failure could go unnoticed, so let's
  # notify release-engineering.
  def auto_prepush_failed?(job)
    job.pub_options['nochannel'] &&
      job_changed_to_status?(job, 'FAILED') &&
      job.pushed_by == User.system
  end

  def job_changed_to_status?(job, status)
    changed_status = job.previous_changes['status']
    changed_status.present? && changed_status[1] == status
  end
end
