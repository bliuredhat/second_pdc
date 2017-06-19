module Tps
  class Scheduler

    #
    # Schedules rhn tps jobs and cdn tps jobs job, aka "dist" jobs
    #
    def self.schedule_tps_jobs(tps_run, args={})
      schedule_rhn_jobs(tps_run, args) + schedule_cdn_jobs(tps_run, args)
    end
    def self.schedule_rhn_jobs(tps_run, args={})
      ensure_jobs(tps_run, :rhn_tps_jobs, RhnTpsJob, Push::Rhn.get_channels_for_tps(tps_run.errata), reschedule_channels(args))
    end
    def self.schedule_cdn_jobs(tps_run, args={})
      ensure_jobs(tps_run, :cdn_tps_jobs, CdnTpsJob, Push::Cdn.get_repos_for_tps(tps_run.errata), reschedule_repos(args))
    end

    #
    # Schedules rhnqa jobs and cdnqa jobs, aka "distqa" jobs
    #
    def self.schedule_distqa_jobs(tps_run, args={})
      schedule_rhnqa_jobs(tps_run, args) + schedule_cdnqa_jobs(tps_run, args)
    end
    def self.schedule_rhnqa_jobs(tps_run, args={})
      ensure_jobs(tps_run, :rhnqa_tps_jobs, RhnQaTpsJob, Push::Rhn.get_channels_for_tps(tps_run.errata), reschedule_channels(args))
    end
    def self.schedule_cdnqa_jobs(tps_run, args={})
      ensure_jobs(tps_run, :cdnqa_tps_jobs, CdnQaTpsJob, Push::Cdn.get_repos_for_tps(tps_run.errata), reschedule_repos(args))
    end

    private

    #
    # Ensures relevant jobs are created and any irrelevant jobs are removed.
    #
    def self.ensure_jobs(tps_run, job_list_method, job_klass, channels_or_repos, reschedule_channels_or_repos)
      # Anything not in channels_or_repos will be unscheduled, so
      # there is no need to reschedule.
      reschedule_channels_or_repos &= channels_or_repos

      rescheduled_jobs = reschedule_jobs(tps_run, job_list_method, reschedule_channels_or_repos)

      new_jobs = uncovered(tps_run, job_list_method, channels_or_repos).collect do |c|
        job = job_klass.new(
            :run => tps_run,
            :arch => c.arch,
            :dist_source => c
        )
        job.save!
        TPSLOG.info "Scheduled #{job_klass} #{job.id} for #{c.name}"
        job
      end
      tps_run.reload

      # jobs scheduled for channels/repos which are no longer relevant should be removed
      tps_run.send(job_list_method).reject{|job| channels_or_repos.include?(job.dist_source)}.each do |job|
        job.destroy
        dist_source_name = job.dist_source.try(:name)
        dist_source_name ||= "deleted channel #{job.channel_id}" if job.channel_id
        dist_source_name ||= "deleted repo #{job.cdn_repo_id}" if job.cdn_repo_id
        TPSLOG.info "Removed #{job_klass} #{job.id} for #{dist_source_name}; no longer relevant"
      end

      new_jobs + rescheduled_jobs
    end

    #
    # Given a list of channels or repos, return the ones that don't already have a tps job
    #
    def self.uncovered(tps_run, job_list_method, channel_or_repo_list)
      covered_items = tps_run.send(job_list_method).map(&:dist_source).uniq
      channel_or_repo_list.reject { |i| covered_items.include?(i) }
    end

    def self.reschedule_jobs(tps_run, job_list_method, reschedule_channels_or_repos)
      tps_run.send(job_list_method).map{|job| [job, job.dist_source]}.
        select{|(job,dist)| reschedule_channels_or_repos.include?(dist)}.
        map do |job,dist|
        TPSLOG.info "Rescheduling #{job.type} #{job.id} (for #{dist.type} #{dist.name})."
        job.reschedule!
        job
      end
    end

    # Return all CDN repos / RHN channels for which TPS jobs should be
    # rescheduled, given a set of changed ErrataBrewMappings (added or
    # removed).
    def self.reschedule_dists(mappings, meth)
      # Only RPMs are relevant for TPS scheduling
      mappings = mappings.select(&:for_rpms?)
      return [] if mappings.empty?

      errata = mappings.first.errata
      out = []
      meth.call(errata, :mappings => mappings) do |build, file, variant, arch, dists, mapped_dists|
        all_dists = (dists || []) + (mapped_dists || [])
        all_dists.uniq!
        TPSLOG.debug "file #{file.filename} goes to #{all_dists.map(&:name).join(', ')}"
        out.concat(all_dists)
      end

      out.uniq!
      if errata.is_pdc?
        out = out.collect {|c| c.service == 'rhn' ? Channel.find_by_name(c.name) : CdnRepo.find_by_name(c.name)}.compact
      end
      out
    end

    def self.reschedule_channels(args)
      reschedule_dists(args[:reschedule_mappings] || [], Push::Rhn.method(:file_channel_map))
    end

    def self.reschedule_repos(args)
      reschedule_dists(args[:reschedule_mappings] || [], Push::Cdn.method(:file_repo_map))
    end
  end
end
