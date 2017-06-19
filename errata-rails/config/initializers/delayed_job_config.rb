#
# Time to wait for a job to finish. Default 4 hours.
#
# The default seems a bit long so let's make it shorter.
#
Delayed::Job.max_run_time = 20.minutes

#
# Whether failed jobs get removed eventually, default true.
# Let's keep them around for diagnostic purposes.
#
Delayed::Job.destroy_failed_jobs = false

#
# Max number of times to attempt a job. Default 25.
#
#Delayed::Job.max_attempts = 25

#
# The time in seconds between polling for jobs, default 5.
#
#Delayed::Worker.sleep_delay = 5

class Delayed::Job
  scope :failing, where('last_error is not null')
  scope :running, where('locked_by is not null')
  scope :untried, where('last_error is null')
end
