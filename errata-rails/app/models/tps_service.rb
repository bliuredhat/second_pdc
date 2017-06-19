class TpsService
  def self.need_remote_host(method_name)
    'jobReport' == method_name
  end

  def ping
    true
  end

  def jobReport(job_id, run_id, result, link, linkdesc, hostname)
    job = TpsJob.find(job_id)
    run = TpsRun.find(run_id)
    state = TpsState.find(:first, :conditions => ['state = ?', result])
    unless job.run == run
      raise "Job id #{job_id} does not belong to run #{run_id}!"
    end
    run.update_job(job, state, link, linkdesc, hostname)
    'ACK'
  end
end
