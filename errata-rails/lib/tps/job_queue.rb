module Tps

  def Tps.advisories_for_job_queue
    Errata.qe.includes([:product, :quality_responsibility, :assigned_to])
  end

  def Tps.get_jobs_in_state(state, advisories=[])
    jobs = []
    advisories.each do |e|
      next unless e.tps_run
      jobs.concat(e.tps_run.tps_jobs.with_states(state))

      #
      # Do not include rhnqa jobs unless the advisory is an RHNQA and
      # tps jobs have finished
      #
      next unless e.rhnqa?
      next unless e.tps_run.jobs_finished?
      jobs.concat(e.tps_run.rhnqa_jobs.with_states(state))
    end
    jobs.reject! {|j| j.is_rhn? && j.channel.nil? }
    return jobs
  end

  # Gets the current queue of open TPS jobs available to be run.
  # Returns a list of hashes with the :job, :errata, and :channel for
  # the tps job
  def Tps.job_queue
    advisories = advisories_for_job_queue
    jobs = get_jobs_in_state(TpsState::NOT_STARTED, advisories)
    available_jobs = []
    jobs.each do |job|
      available_jobs.push({ :job => job, :errata => job.errata, :repo_name => job.repo_name }) unless job.repo_name.nil?
    end
    return available_jobs.sort {|a,b| a[:job].id <=> b[:job].id}
  end

  # Publishes the queue of open tps jobs to public/tps.txt
  def Tps.publish_job_queue
    TPSLOG.info "Publishing new job queue"
    jobs = job_queue
    tps_txt = Rails.root.join("public/tps.txt")
    FileWithSanityChecks::TpsTxtFile.new(tps_txt).prepare_file do |f|
      write_to(jobs, f)
    end.check_and_move
  end

  def Tps.write_to(queue, f)
    queue.each do |j|
      f.puts TpsJob.tps_txt_queue_entry(j[:job], j[:errata], j[:repo_name])
    end
    f.close
  end

end

