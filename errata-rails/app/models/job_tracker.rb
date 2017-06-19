class JobTracker < ActiveRecord::Base
  belongs_to :user
  has_many :job_tracker_delayed_maps
  has_many :delayed_jobs,
           :class_name => 'Delayed::Job',
           :through => :job_tracker_delayed_maps

  after_update do
    if send_mail? && state_changed?
      if 'FINISHED' == state
        Notifier.job_tracker_completed(self).deliver
      elsif 'FAILED' == state
        Notifier.job_tracker_failed(self).deliver
      end
    end
  end

  # Creates a JobTracker. Uses DelayedJobObserver to
  # ensure that any jobs created within the block are
  # added to the new tracker
  def self.track_jobs(name, description, opts = {}, &block)
    user = opts[:user] || User.current_user
    send_mail = opts.include?(:send_mail) ? opts[:send_mail] : true
    self.transaction do
      tracker = self.create!(:name => name, :description => description, :user => user, :send_mail => send_mail, :max_attempts => opts[:max_attempts], :total_job_count => 0)
      ThreadLocal.with_thread_locals({:job_tracker => tracker}) do
        yield
      end
      if tracker.total_job_count != 0
        tracker
      else
        tracker.destroy
        nil
      end
    end
  end

  def jobs
    delayed_jobs.collect {|j| DelayedJobExhibit.new(j)}
  end

  def job_failed(job)
    if !delayed_jobs.untried.any?
      if should_give_up?
        self.fail!
      else
        state = 'STALLED'
      end
      save
    end
  end

  def job_completed(job)
    return if state == 'FAILED'
    new_state = 'RUNNING'
    if jobs_except_for(job).any?
      unless jobs_except_for(job).untried.any?
        new_state = 'STALLED'
      end
    else
      new_state = 'FINISHED'
    end
    update_attribute(:state, new_state)
  end

  def jobs_except_for(job)
     delayed_jobs.where('delayed_jobs.id != ?', job)
  end

  def has_unfinished_jobs?
    delayed_jobs.any?
  end

  def should_give_up?
    return false if max_attempts.nil?
    delayed_jobs.any? && delayed_jobs.all? {|dj| dj.attempts >= max_attempts}
  end

  # Set state to FAILED and cancel any pending jobs
  def fail!
    return if state == 'FAILED'
    JobTracker.transaction do
      update_attribute(:state, 'FAILED')
      Delayed::Job.destroy_failed_jobs ? delayed_jobs.each(&:destroy) : delayed_jobs.each do |dj|
        dj.update_attribute(:failed_at, Time.now)
      end
    end
  end
end

