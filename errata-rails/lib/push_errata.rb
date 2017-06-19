module PushErrata

  def self.relprep
    Errata.valid_only.rel_prep
  end

  def self.move_rel_prep_to_push_ready
    user = User.find_by_login_name 'errata/beehive@redhat.com'
    self.relprep.each do |e|
      next unless e.publish_date_passed?
      next unless e.push_ready_blockers.empty?
      begin
        e.change_state!(State::PUSH_READY, user, "Automated state transition to PUSH_READY")
      rescue => e
        Rails.logger.error "Error in push ready transition #{e.message}"
      end
    end
  end

  # Find all errata eligible for pre-push to RHN/CDN live and trigger their pre-push jobs.
  def self.trigger_prepush_for_eligible_errata
    unless Settings.use_prepush
      Rails.logger.debug 'Not doing live pre-push; disabled by server setting'
      return
    end

    errata_for_prepush.each do |e|
      [RhnLivePushJob, CdnPushJob].each do |push_job_class|
        # If there has been any push of this type since last respin (whether a regular
        # job, or manual or auto nochannel), then something/someone else is/was already
        # trying to push this advisory, so an automatically triggered job is probably not
        # wanted.
        next if e.push_jobs_since_last_state(push_job_class, 'NEW_FILES').any?

        trigger_prepush(push_job_class, e)
      end
    end
  end

  def self.errata_for_prepush
    # Must be in appropriate state. QE is too early and PUSH_READY is too late.
    # TODO Support PDC
    LegacyErrata.rel_prep.
      joins(:errata_brew_mappings => [:brew_build]).
      group(:errata_id).
      # All of the associated brew builds must be signed
      having('MIN(`brew_builds`.`signed_rpms_written`) = 1')
  end
  private_class_method :errata_for_prepush

  def self.trigger_prepush(push_job_class, errata)
    job = push_job_class.new(:errata => errata, :pushed_by => User.system)

    job.pub_options     = {'push_files'    => true,
                           'push_metadata' => true,
                           'nochannel'     => true}
    job.pre_push_tasks  = []
    job.post_push_tasks = []

    blockers = job.push_blockers
    if blockers.any?
      Rails.logger.info(
        "#{push_job_class.name} pre-push for #{errata.advisory_name} not permitted: " +
        blockers.join(', '))
      return
    end

    ActiveRecord::Base.transaction do
      if job.save
        Rails.logger.info "Triggered live pre-push job #{job.id}."
        job.info "This is a pre-push job triggered automatically by Errata Tool."
        job.submit_later
        return
      end
    end

    # This is not considered fatal, if some particular errata can't be pre-pushed for
    # any reason then we'll keep going and do as much as we can.
    Rails.logger.warn "Failed to trigger live pre-push #{push_job_class.name} for " \
         "#{errata.advisory_name}: #{job.errors.full_messages.join(', ')}"
  end
  private_class_method :trigger_prepush
end

