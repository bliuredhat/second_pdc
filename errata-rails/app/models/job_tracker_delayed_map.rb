class JobTrackerDelayedMap < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :job_tracker
  belongs_to :delayed_job,
             :class_name => 'Delayed::Job'
  validates_uniqueness_of :delayed_job_id

  after_destroy do
    job_tracker.job_completed(delayed_job)
  end
end
