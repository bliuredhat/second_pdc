module LivePushTasks
  extend ActiveSupport::Concern
  include ApplicationHelper

  PRE_PUSH_TASKS = {
    "set_issue_date" => {
      :shadow      => true,
      :description => "Set the 'issue date' to today; Only check this if this errata " +
      "has previously been pushed live, yet you want to show today's date " +
      "as the issue date",
    },

    "set_update_date" => {
      :default     => true,
      :shadow      => true,
      :description => "Set the 'updated date' to today; Only uncheck this for changes like " +
      "adding a CVE name, typo fix, or to fix an infrastructure issue",
    },

    "reset_update_date" => {
      :default     => false,
      :shadow      => false,
      :description => "Set the 'updated date' to the issue date; Only set this when  " +
      "fixing a bad 'updated date'",
    },

    "set_live_id" => {
      :mandatory   => true,
      :shadow      => true,
      :description => "Set a live ID for the errata",
    },

    'set_in_push'  => {
      :mandatory   => true,
      :shadow      => true,
      :description => 'Puts the advisory in the IN_PUSH state'
    },
  }

  POST_PUSH_TASKS = {
    # For advisories doing both a CDN and RHN push, push task execution is customized by:
    #
    #  :after => if the advisory has push targets of these types, all of those pushes must complete
    #            before the task will be run.
    #            e.g. [:cdn,:rhn_live] ensures a task is run only after both RHN and CDN pushes
    #            complete.
    #
    #            Note that this doesn't guarantee the task runs only once.  For example,
    #            an :after => :cdn task could be run twice if a CDN push completes first, followed
    #            by an RHN push.  In both cases, the task ran 'after' the CDN push completed.
    #
    #  :only => push task is only associated with push targets of the given type.
    #           e.g. :rhn_live to ensure a task runs only once and only when an RHN push completes.
    #

    "push_oval_to_secalert" => {
      :rhsa_only   => true,
      :default     => true,
      :description => "Push oval to secalert",
      :after       => [:rhn_live, :cdn],
    },

    "push_xml_to_secalert" => {
      :rhsa_only   => true,
      :default     => true,
      :description => "Push XML to secalert for CVRF",
      :after       => [:rhn_live, :cdn],
    },

    "update_push_count" => {
      :mandatory   => true,
      :shadow      => true,
      :description => "Increase the push count by one.",
      :after       => [:rhn_live, :cdn],
    },

    "update_bugzilla" => {
      :default     => true,
      :description => "Close the errata's bugs as CLOSED/ERRATA",
      :after       => [:rhn_live, :cdn],
    },

    "update_jira" => {
      :default     => true,
      :description => "Close the errata's JIRA issues",
      :after       => [:rhn_live, :cdn],
    },

    "move_pushed_errata" => {
      :default     => true,
      :description => "Call releng's move pushed errata script.",
      :after       => [:rhn_live, :cdn],
    },

    "request_translation" => {
      :rhsa_only   => true,
      :default     => true,
      :description => "Request translation of errata text",
      :after       => [:rhn_live, :cdn],
    },

    "mark_errata_shipped" => {
      :mandatory   => true,
      :shadow      => true,
      :description => "Change the status of errata to shipped_live.",
      :after       => [:rhn_live, :cdn, :cdn_docker],
    },

    "check_error" => {
      :mandatory   => true,
      :shadow      => true,
      :description => "Change the status of errata to rel_prep if error occurred.",
      :only        => [:rhn_live, :cdn, :cdn_docker],
    }
  }

  def task_availability(task_name, task_def)
    # If we're doing a tasks-only push, just do every task we were
    # asked to do.  See bug 1130063.
    return Available.new if self.skip_pub_task_and_post_process_only?

    after_push_types = Array.wrap(task_def[:after])
    after_push_types &= self.errata.supported_push_types

    # task should only be run if every applicable push type mentioned
    # in :after has completed push (other than self, which may be
    # about to complete).
    applicable_policies = after_push_types.
      map{|type| Push::Policy.new(self.errata, type)}.
      select(&:push_applicable?)

    blocking_policies = applicable_policies.reject do |pol|
      # The "push type" on push job is the "push target" on push policy :(
      pol.has_pushed? || pol.push_target == self.push_type
    end

    if blocking_policies.empty?
      Available.new
    else
      policies_string = lambda do |ps|
        ps.map(&:push_target).map(&:to_s).sort.join(', ')
      end
      needed = policies_string[applicable_policies]
      missing = policies_string[blocking_policies]
      why = "#{missing} push is not complete. Depends on: #{needed}"
      NotAvailable.new(why)
    end
  end

  def valid_post_push_tasks_for_push_type(type)
    out = POST_PUSH_TASKS.dup
    unless errata.is_security?
      out.reject! { |k,v| v[:rhsa_only] }
    end
    out.reject! {|k,v| types = Array.wrap(v[:only]); !types.empty? && !types.include?(type)}
    out
  end

  # rhn live specific tasks
  def task_set_live_id
    unless errata.has_live_id_set?
      old_advisory = errata.advisory_name
      LiveAdvisoryName.set_live_advisory! errata
      info "Changed #{old_advisory} to public name: #{errata.advisory_name}"
    end
  end

  def task_set_in_push
    if [State::IN_PUSH, State::SHIPPED_LIVE].include?(errata.status)
      info "State already #{errata.status}"
      return
    end

    info "Changing state to IN_PUSH by #{self.pushed_by.to_s}"
    errata.change_state!(State::IN_PUSH, self.pushed_by)
    info 'Advisory now IN_PUSH'
  end

  # TODO: if push_count=0, call these two
  #unless @errata.pushcount?...
  def task_set_issue_date
    errata.issue_date = Time.now
    errata.save!
    info "Updated Issue date"
  end

  def task_reset_update_date
    errata.update_date = errata.issue_date
    errata.save!
    info "Reset Update date"
  end

  def task_set_update_date
    errata.update_date = Time.now
    errata.save!
    info "Updated Update date"
  end

  def task_update_push_count
    errata.pushcount = errata.pushcount + 1
    errata.save!
    info "Push count increased"
  end

  def task_update_bugzilla
    # Modify Bugzilla by updating status/resolution and adding comments
    # to bug numbers listed in the errata report.
    info "Closing bugs..."
    Bugzilla::CloseBugJob.close_bugs(errata)
    info "Bugs put into queue to close"
  end

  def task_check_jira
    # This task was obsoleted by bug 1147676.  An empty implementation
    # needs to hang around for a while so that push jobs persisted
    # prior to that bug fix won't crash after the upgrade.
    info 'check_jira is an obsolete task. Not doing anything.'
  end

  def task_update_jira
    info "Closing JIRA issues..."
    Jira::CloseIssueJob.close_issues(errata)
    info "Issues put into queue to close"
  end

  def task_push_oval_to_secalert
    # OVAL increments pushcount += 1
    # oval push to secalert always occurs after push count is incremented.
    count = errata.pushcount
    begin
      errata.pushcount -= 1
      Push::Oval.push_oval_to_secalert(errata, self)
    rescue => e
      error "Error occurred pushing OVAL errata to secalert: #{e.to_s}"
    ensure
      errata.pushcount = count
    end
  end

  def task_push_xml_to_secalert
    begin
      Push::ErrataXmlJob.enqueue(errata)
    rescue => e
      error "Error occurred pushing XML errata to secalert: #{e.to_s}"
    end
  end

  def task_request_translation
    return unless errata.is_security?
    info "Requesting translation"
    viewer = TextRender::ErrataRenderer.new(errata,'errata/errata_text')
    errata_text = viewer.get_text
    Notifier.request_translation(errata, errata_text).deliver
    info "translation requested"
  end

  def task_move_pushed_errata
    info "Calling move-pushed-erratum for #{errata.shortadvisory}"
    if Rails.env.production?
      KerbCredentials.refresh
      res = `/mnt/redhat/scripts/rel-eng/utility/move-pushed-erratum #{errata.shortadvisory} 2>&1`
      unless $?.exitstatus == 0
        raise StandardError, "move-pushed-erratum returned with nonzero exit status: #{res}"
      end
      info res
    else
      logger.debug "Would call: `/mnt/redhat/scripts/rel-eng/utility/move-pushed-erratum #{errata.shortadvisory} 2>&1`"
    end
    info "move-pushed-erratum complete"
  end

  def task_mark_errata_shipped
    info "Already SHIPPED_LIVE" if errata.status == State::SHIPPED_LIVE
    return if errata.status == State::SHIPPED_LIVE

    return unless should_move_to_shipped_live?

    ActiveRecord::Base.transaction do
      # Special case to support scenario mentioned in bug 1130063:
      # User wants to run post-push tasks only and wants the advisory to go
      # to SHIPPED_LIVE.  However, that requires the current status to
      # be IN_PUSH.
      # That's normally done by a pre-push task, but those are skipped when
      # not triggering pub.  So do it here instead.
      if errata.status == State::PUSH_READY && self.skip_pub_task_and_post_process_only?
        info "Changing state to IN_PUSH by #{self.pushed_by.to_s} (in preparation for SHIPPED_LIVE)"
        errata.change_state!(State::IN_PUSH, self.pushed_by)
        info "Advisory now IN_PUSH"
      end

      errata.actual_ship_date ||= Time.now
      errata.published = 1 unless pub_options['shadow']
      errata.published_shadow = 1 if pub_options['shadow']
      info "Changing state to SHIPPED_LIVE by #{self.pushed_by.to_s}"
      errata.change_state!(State::SHIPPED_LIVE, self.pushed_by)
      info 'Advisory now SHIPPED_LIVE'
    end
  end

  # This task changes the advisory state if mandatory push types have failed
  # (e.g. RHN, CDN).
  #
  # Important: this is not only called by the usual post-push task mechanism,
  # but it's also directly called if the push job is stopped abnormally, e.g.
  # cancelled by user.
  def task_check_error
    # nochannel job failure should not result in any state changes
    return if is_nochannel?

    policies = Push::Policy.policies_for_errata(errata, {:mandatory => true}).select(&:push_applicable?)
    push_jobs = policies.map(&:push_job_since_last_push_ready).compact

    # nochannel jobs never count toward whether advisory push is considered
    # to have failed
    push_jobs.reject!(&:is_nochannel?)

    failed_jobs = push_jobs.select(&:failed?)
    active_jobs = push_jobs.select(&:in_progress?)

    # Move the status of errata to PUSH_READY if:
    # - no more active push jobs are running
    # - and there is at least one failed push job.
    if active_jobs.empty? && failed_jobs.any?
      comment = "Mandatory push job(s) have failed: #{failed_jobs.map(&:id).join(', ')}"
      error comment
      move_advisory_to_push_ready(comment)
    end
  end

  def move_advisory_to_push_ready(comment)
    info "Changing state to PUSH_READY"
    if errata.status == State::PUSH_READY
      info "Already PUSH_READY"
    elsif errata.status == State::IN_PUSH
      errata.change_state!(State::PUSH_READY, User.system, comment)
      info "Advisory now PUSH_READY"
    else
      error "Transition #{errata.status} => PUSH_READY is invalid"
    end
  end

  def should_move_to_shipped_live?
    # Don't move to SHIPPED_LIVE if some applicable policy hasn't yet pushed.
    unpushed = Push::Policy.policies_for_errata(errata, {:mandatory => true}).
      select(&:push_applicable?).
      reject(&:has_pushed?)

    # (Note that there's no need for special handling to include
    # consideration of _this_ push job in the above check.  This job
    # is expected to be in POST_PUSH_PROCESSING already and so should
    # be is_committed?, thus counting as "pushed".

    out = unpushed.empty?
    if !out
      info "Advisory shouldn't move to SHIPPED_LIVE because #{unpushed.map(&:push_target).join(', ')} push is not complete"
    end
    out
  end
end
