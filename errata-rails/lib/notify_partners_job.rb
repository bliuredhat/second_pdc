class NotifyPartnersJob
  # Advisory status which will cause notification to be silently dropped
  DROP_STATUS = %w[
    DROPPED_NO_SHIP
    SHIPPED_LIVE
  ]

  # Advisory status which will cause notification to be deferred
  DEFER_STATUS = %w[
    NEW_FILES
  ]

  def initialize(index)
    @index = index.id
  end

  def perform
    @rerun = false

    index = StateIndex.find(@index)
    return if should_forget?(index)

    if should_defer?(index)
      @rerun = true
      return
    end

    errata = index.errata
    delay = ((Time.now - index.created_at)/60/60).to_i

    MAILLOG.debug "Sending partner notification for #{errata.fulladvisory} (delayed by #{delay} hours)"

    # If this notification is for the initial QE, notify of a "new errata",
    # otherwise notify of "changed files".
    #
    # Note however that partners are _not_ guaranteed to always receive a "new
    # errata" notification before "changed files", for example if the advisory
    # has transitioned through NEW_FILES twice and only became unembargoed after
    # the second transition.
    #
    # This is thought to be acceptable since this only happens for a minority of
    # errata, and it's worked this way since the notification mails were
    # introduced.
    if index.prior_index.initial_index?
      Notifier.partners_new_errata(errata).deliver
    else
      Notifier.partners_changed_files(errata).deliver
    end
  end

  # True if we should stop attempting to deliver this notification.
  # Mostly due to state changes since the job was originally enqueued.
  def should_forget?(index)
    e = index.errata

    log = lambda do |reason|
      MAILLOG.info "Dropping partner notification for #{e.fulladvisory}: #{reason}"
    end

    if DROP_STATUS.include?(e.status)
      log[e.status]
      return true
    end

    # If the advisory has gone to NEW_FILES again some time later, drop this
    # notification, because the next NEW_FILES transition would have enqueued
    # another one.  We don't want to send useless duplicate notifications.
    respun = StateIndex.
      where(:errata_id => e.id, :current => 'NEW_FILES').
      where('id > ?', index.id).
      order('id asc').
      find \
        do |idx|
          e.build_mapping_class.added_at_index(idx).any? ||
            e.build_mapping_class.dropped_at_index(idx).any? ||
            FiledBug.added_at_index(idx).any? ||
            DroppedBug.dropped_at_index(idx).any?
        end

    if respun
      log["respun at #{respun.created_at}"]
      return true
    end

    false
  end

  # True if notification should not be delivered now,
  # but possibly should be delivered later.
  def should_defer?(index)
    errata = index.errata

    delay = ((Time.now - index.created_at)/60/60).to_i
    log = lambda do |str|
      MAILLOG.debug "#{str} for #{errata.fulladvisory}"
    end

    if DEFER_STATUS.include?(errata.status)
      log["Wrong status #{errata.status} to notify"]
      return true
    end

    unless errata.allow_partner_access?
      log['Not safe to send partner notification']
      return true
    end
  end

  def rerun?
    @rerun
  end

  def next_run_time
    Settings.partner_notify_check_interval.from_now
  end

  def self.maybe_enqueue(index)
    return unless index.errata.product.notify_partners?

    job = NotifyPartnersJob.new(index)
    Delayed::Job.enqueue(job, 2)
  end
end
