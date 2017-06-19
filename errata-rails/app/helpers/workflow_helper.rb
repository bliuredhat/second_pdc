module WorkflowHelper
  include ActionView::Helpers::DateHelper

  def state_prevent_or_allow_reasons(to_state)
    def reason_helper(reasons, test_ok, ok_message, block_message, info_only)
      ok_message = [ok_message] unless ok_message.is_a? Array
      block_message = [block_message] unless block_message.is_a? Array
      if test_ok
        reasons[info_only ? :info : :allow] += ok_message if ok_message.any?
      else
        reasons[info_only ? :info : :block] += block_message
      end
      reasons
    end

    reasons = { :allow => [], :block => [], :info => [] }
    t = StateTransition.find_by_from_and_to @errata.status, to_state
    guards = @errata.state_machine_rule_set.state_transition_guards.where(:state_transition_id => t)
    (guards.blocking + guards.waivable).each do |g|
      reasons = reason_helper(reasons, g.transition_ok?(@errata), g.ok_message(@errata), g.failure_message(@errata), false)
    end
    guards.informative.each do |g|
      reasons = reason_helper(reasons, g.transition_ok?(@errata), g.ok_message(@errata), g.failure_message(@errata), true)
    end
    reasons
  end

  #
  # Save putting the btn and btn-mini bootstrap classes in every link below...
  #
  def workflow_action_link(title, link, opts={})
    link_to(title, link, {:class=>'btn btn-mini'}.merge(opts))
  end

  def push_job_link(job, text)
    workflow_action_link("#{text} (#{job.status})",
                         { :controller => 'push', :action => 'push_results', :id => job })
  end

  #
  # Last push button helper. push_job_class is FtpPushJob, RhnStagePushJob or RhnLivePushJob
  #
  def last_push_link(push_job_class, errata)
    if (last_push = push_job_class.last_push(errata))
      push_job_link(last_push, 'Last job')
    end
  end

  #
  # Shows link to last nochannel job, if any. This is represented to the user as a
  # "pre-push" of the live content
  #
  def last_prepush_link(push_job_class, errata)
    jobs_since_respin = errata.push_jobs_since_last_state(push_job_class, 'NEW_FILES')
    if (job = jobs_since_respin.nochannel.order('id desc').first)
      push_job_link(job, 'Pre-push')
    end
  end

  #
  # Won't show the link if here are no pushes of the given type since having the
  # button there tends to imply there might be a relevant push job to look at.
  #
  def push_history_link(push_job_class, errata)
    if push_job_class.for_errata(errata).any?
      workflow_action_link("Push History", { :controller => 'push', :action => 'push_history_for_errata', :id => errata })
    end
  end

  #----------------------------------------------------------------
  #
  # Each step method return a hash of things that can be rendered.
  #
  # (Might refactor this later...
  # Maybe should make classes for these things instead of hashes.
  # eg, have a base class and subclasses for each different 'step'...)
  #
  def workflow_step_helper(step_name)
    raise "Unknown step #{step_name}" unless WorkflowHelper.private_method_defined? step_name
    method(step_name).call
  end

  #----------------------------------------------------------------
  private

  def tps_finished
    stats = @errata.tps_run.job_stats
    {
      :name => 'TPS Tests',
      :status => (@errata.tps_finished? ? :ok : :block),
      :actions => [
                   workflow_action_link("View", {:action => 'errata_results', :controller => 'tps', :id => @errata.tps_run })
                  ],
      :info => if !@errata.tps_run.tps_jobs.any?
                 ['No TPS test is scheduled.']
               else
                 [stats.to_a.collect {|a| a.join(': ')}.join(', ')]
               end
    }
  end

  def rhnqa_finished
    stats = @errata.tps_run.rhnqa_stats
    tps_job_blockers = @errata.tps_job_blockers
    {
      :name => 'RHNQA TPS Tests',
      :status => (@errata.tpsrhnqa_finished? ? :ok : :block),
      :actions => [
                   workflow_action_link("View", {:action => 'rhnqa_results', :controller => 'tps', :id => @errata.tps_run })
                  ],
      :info => if !@errata.tps_run.rhnqa_jobs.any?
                 ['No RHNQA TPS test is scheduled.']
               elsif !tps_job_blockers.empty?
                 tps_job_blockers
               else
                 [stats.to_a.collect {|a| a.join(': ')}.join(', ')]
               end
    }
  end

  def edit
    {
      :name => 'Add/Update Advisory Details',
      :status => :ok,
      :actions => [
                   (workflow_action_link('Edit advisory', {:action => :edit, :id => @errata }) if @errata.allow_edit?)
                  ],
      :info => [
                "#{@errata.revision - 1} edits",
                ("Can't edit in status #{@errata.status}" if !@errata.allow_edit?),
               ],
    }

  end

  def set_text_only_rhn_channels
    dists = @errata.text_only_channel_list.get_all_channel_and_cdn_repos
    require_dists = @errata.product.text_only_advisories_require_dists?
    supports_rhn_live_or_cdn = @errata.supports_rhn_live? || @errata.supports_cdn?
    status =  if !require_dists || ( dists.any? && supports_rhn_live_or_cdn )
                :ok
              else
                :wait
              end
    action = [ workflow_action_link('Set',
                                    {:action => :text_only_channels,
                                     :id => @errata }) ]
    info = if require_dists
             if dists.any?
               supports_rhn_live_or_cdn ?
                 "Current: #{dists.map(&:name).join(', ')}" :
                 "None of the selected RHN Channels or CDN Repos have product versions with live push targets enabled."
             else
               "Must set at least one RHN Channel or CDN Repo"
             end
           else
             dists.any? ?
               "Current: #{dists.map(&:name).join(', ')}" :
               "RHN Channels or CDN Repos not required"
           end
    {
      :name => 'RHN Channels/CDN Repos',
      :status => status,
      :actions => action,
      :info => Array.wrap(info),
    }
  end

  def update_brew_builds
    no_plc = @errata.build_mappings.for_rpms.without_product_listings
    reload = if no_plc.any?
      link_to(
        "Reload #{n_thing_or_things(no_plc.size, 'missing product listing')}",
        erratum_reload_builds_path(@errata, :no_rpm_listing_only => "1"),
        :method => :post, :class => "btn btn-mini")
    end
    no_cf = @errata.build_mappings.for_rpms.without_current_files
    reload_cf =
      if no_cf.any?
        link_to(
          "Reload #{n_thing_or_things(no_cf.size, 'build')} with missing current files records",
          erratum_reload_builds_path(@errata, :no_current_files_only => "1"),
          :method => :post, :class => "btn btn-mini", :title => "current files: When a build is added to an advisory, Errata Tool keeps a record of the files associated with that build. This is based on the product listings but could be different from the list in Builds tab.")
      end

    {
      :name => 'Add/Update Brew Builds',
      :status => if @errata.brew_builds.empty? || no_plc.any? || no_cf.any?
                    :wait
                  else
                    :ok
                  end,
      :actions => [
                   (workflow_action_link("Edit builds", {:action => 'list_files', :controller=> 'brew', :id => @errata}) if @errata.status_is?(:NEW_FILES)),
                   reload,
                   reload_cf,
                  ],
      :info => [
                ("(Can update builds only when status is NEW_FILES)" unless @errata.status_is?(:NEW_FILES)),
                added_build_count_message,
               ],
    }

  end

  def added_build_count_message
    build_count = @errata.brew_builds.count
    mapping_count = @errata.build_mappings.count
    "#{n_thing_or_things(build_count, 'build')} added" +
      (build_count == mapping_count ? '' : " (#{n_thing_or_things(mapping_count, 'build mapping')})")
  end

  def update_brew_file_meta
    missing = @errata.brew_files_missing_meta
    present = @errata.brew_file_meta.complete
    {
      :name => 'Add/Update File Attributes',
      :status => if missing.any?
                    :block
                  else
                    :ok
                  end,
      :actions => [
                   (workflow_action_link("Edit files", {:action => 'edit_file_meta', :controller=> 'brew', :id => @errata}) if @errata.filelist_unlocked?),
                  ],
      :info => [
                ("(Can update file attributes only when status is NEW_FILES)" unless @errata.filelist_unlocked?),
                "#{n_thing_or_things(present.count, 'file')} with attributes",
                ("#{n_thing_or_things(missing.count, 'file')} are missing attributes" if missing.any?)
               ],
    }
  end


  def rpm_diff_finished
    rpmdiff_stats = @errata.rpmdiff_stats
    {
      :name => 'RPMDiff Tests',
      :status => if @errata.brew_builds.empty?
                    # This condition will never be fulfilled because require_rpmdiff? always return
                    # false if no brew build is added. Still keep this codes in case...
                    :wait
                  elsif @errata.rpmdiff_finished?
                    :ok
                  else
                    :block
                  end,
      :actions => [
                   (if @errata.brew_builds.any?
                     workflow_action_link("View", {:action => 'list', :controller => 'rpmdiff', :id => @errata})
                   end)
                  ],
      :info => if @errata.brew_builds.empty?
                 [
                   "<span class='superlight'><i>Builds not yet added</i></span>".html_safe
                 ]
               elsif @errata.rpmdiff_runs.current.empty?
                 ["RPMDiff tests are not scheduled"]
               else
                 [
                   "Passed: #{rpmdiff_stats[RpmdiffScore::PASSED]}",
                   "Failed: #{rpmdiff_stats[RpmdiffScore::FAILED]}",
                   "Needs Inspection: #{rpmdiff_stats[RpmdiffScore::NEEDS_INSPECTION]}",
                   "Pending #{rpmdiff_stats[RpmdiffScore::QUEUED_FOR_TEST]}",
                   "Waived: #{rpmdiff_stats[RpmdiffScore::WAIVED]}",
                 ]
               end
    }

  end

  def rpm_diff_review_finished
    results = @errata.rpmdiff_results.where(:score => RpmdiffScore::WAIVED)
    waivers = RpmdiffWaiver.latest_for_results(results).to_a
    total = waivers.count
    acked = waivers.count(&:acked?)
    {
      :name => 'RPMDiff Review',
      :status => if @errata.brew_builds.empty?
                    :wait
                  elsif @errata.rpmdiff_review_finished?
                    :ok
                  elsif @errata.state_machine_rule_set.state_transition_guards.blocking.where(:type => RpmdiffReviewGuard).any?
                    :block
                  else
                    :wait
                  end,
      :actions => [
                   (if @errata.brew_builds.any?
                     workflow_action_link("Review Waivers", {:action => 'manage_waivers', :controller => 'rpmdiff', :id => @errata})
                   end)
                  ],
      :info => if @errata.brew_builds.empty?
                  [
                    "<span class='superlight'><i>Builds not yet added</i></span>".html_safe
                  ]
                else
                  [
                    "Waivers: #{total}",
                    "Approved Waivers: #{acked}",
                  ]
                end
    }

  end

  def external_tests_finished
    # This workflow item is specific to the NEW_FILES => QE step.
    test_types = @errata.required_external_tests_for_transition(:from => 'NEW_FILES', :to => 'QE')
    test_runs = @errata.external_test_runs.where(:external_test_type_id => test_types)

    {
      :name => 'External Tests',
      # TODO: Actually status should just be info icon for non-blocking transitions guards
      :status => if @errata.all_external_test_runs_passed?(test_types)
                    :ok
                  elsif test_runs.empty?
                    :wait
                  else
                    :block
                  end,
      :actions => if test_runs.any?
                    @errata.external_tests_required(test_types).map do |test_type|
                      workflow_action_link("View #{test_type.tab_name}", {:controller=>'external_tests', :action=>'list', :id=>@errata, :test_type=>test_type.name})
                    end
                  else
                    []
                  end,
      :info => if test_runs.empty?
                  [
                    "<span class='superlight'><i>Test runs not yet added</i></span>".html_safe
                  ]
                else
                  [
                    "Passed or waived #{test_runs.active.select(&:passed_ok?).count} of "+
                    "#{test_runs.active.count} current test runs.",
                  ]
                end
    }
  end

  def abi_diff_finished
    {
      :name => 'ABI Diff Tests',
      :status => if @errata.brew_builds.empty?
                   # rpmdiff_finished? returns true when there are no builds added yet.
                    # So am doing this extra test and won't show a green tick in that case...
                    :wait
                  elsif @errata.abidiff_finished?
                    :ok
                  else
                    :block
                  end,
      :actions => [
                   (if @errata.brew_builds.any?
                     workflow_action_link("View", {:action => 'list', :controller => 'abidiff', :id => @errata})
                   end)
                  ],
      :info => if @errata.brew_builds.empty?
                  [
                    "<span class='superlight'><i>Builds not yet added</i></span>".html_safe
                  ]
                else
                  [
                    "Passed: #{@errata.abidiff_runs.passed.count}",
                    "Blocking: #{@errata.abidiff_runs.blocking.count}",
                    "Started:  #{@errata.abidiff_runs.started.count}",
                    "Failed:  #{@errata.abidiff_runs.failed.count}"

                  ]
                end
    }

  end

  def view_qa_request
    {
      :name => 'Request QA',
      :status => if @errata.status_is?(:NEW_FILES) && state_prevent_or_allow_reasons(State::QE)[:block].empty?
                   :wait
                 elsif !@errata.status_in?(:NEW_FILES, :DROPPED_NO_SHIP)
                   :ok
                 else
                   :block
                 end,
      :actions => [
                   (link_to('Move to QE', "#", :class=>'btn btn-mini open-modal', :data => { 'modal-id' => 'change_state_modal' }) if @errata.status_is?(:NEW_FILES))
                  ],
      # This step is basically just changing state from NEW_FILES to QE, so we
      # can use this. I guess...
      :info => [
                state_prevent_or_allow_reasons(State::QE).values.sort.flatten,
                "Current state: #{status_and_deleted_and_closed_display(@errata)}", # not sure why we show this here, but the old page did it so let's do it too for now at least.
                ("Resolution: #{@errata.resolution}" if @errata.resolution.present?), # ditto
               ],
    }

  end

  def docs_approval
    {
      :name => 'Docs Approval',
      :status => (
                  if @errata.docs_approved?
                    :ok
                  elsif @errata.docs_approved_or_requested?
                    # Waiting to approve
                    :wait
                  else
                    # Waiting to request approval
                    :wait
                  end
                  ),
      :actions => [
                   workflow_action_link('View docs', {:controller=>:docs,:action=>:show,:id=>@errata}),
                   (if !@errata.docs_approved_or_requested?
                      workflow_action_link('Request approval', {:controller=>:docs,:action=>:request_approval,:id=>@errata}, :method=>:post)
                    end)
                  ],
      :info => [
                @errata.docs_status_text,
               ],
    }

  end

  def rcm_push_requested
    {
      :name => 'RCM Push Requested',
      :status => :ok,
      :actions => [],
      :info => [ @errata.rcm_push_requested_text ],
    }
  end

  def security_approval
    {
      :name => 'Product Security Approval',
      :status => (
                  if @errata.security_approved?
                    :ok
                  elsif @errata.status_allows_security_approval?
                    # Waiting for approval or waiting for request
                    :wait
                  else
                    :block
                  end
                  ),
      :actions => [
                   (if @errata.can_request_security_approval?
                      workflow_action_link('Request Approval', {:controller=>:errata, :action=>:request_security_approval, :id=>@errata}, :method => :post)
                    end),
                   (if @errata.can_approve_security?
                      workflow_action_link('Approve', {:controller=>:errata, :action=>:security_approve, :id=>@errata}, :method => :post)
                    end),
                   (if @errata.can_disapprove_security?
                      workflow_action_link('Disapprove', {:controller=>:errata, :action=>:security_disapprove, :id=>@errata}, :method => :post)
                    end),
                  ],
      :info => [
                @errata.security_approval_text,
               ],
    }

  end

  def sign_advisory
    errata_is_signed = @errata.is_signed?
    {
      :name => "Sign Advisory",
      :status => if @errata.brew_builds.empty?
                    :block
                  elsif errata_is_signed
                    :ok
                  elsif @errata.sign_requested?
                    # Waiting for someone to sign
                    :wait
                  else
                    # Waiting for someone to request
                    :wait
                  end,
      :actions => [
                   # More weird looking lists
                   # The if block returns nil if the condition is not true
                   # Slightly more readable than trailing condition, eg (link_to(...) if condition),
                   (if @user.in_role?('signer')
                      workflow_action_link("Revoke Bad Signatures", {:action => :revoke_signatures, :controller => :signing, :id => @errata},
                                           :confirm => 'Only do this if the signature state is bad and advisory needs to be re-signed!', :method => :post)
                    end),
                   (if !errata_is_signed && !@errata.sign_requested? && @user.can_request_signatures?
                      workflow_action_link("Request Signatures", {:action=>:request_signatures, :controller => :signing, :id=>@errata}, :method=>:post)
                    end),
                   (if !errata_is_signed
                      workflow_action_link('Refresh Signature State', {:action => :check_signatures, :controller => :brew, :id => @errata}, :method => :post)
                    end),
                  ],
      :info => [
                (if @errata.brew_builds.empty?
                    "<span class='superlight'><i>Builds not yet added</i></span>".html_safe
                 elsif errata_is_signed
                   "All files signed"
                 elsif @errata.sign_requested?
                   "Signatures have been requested."
                 end),
               ],
    }

  end

  def stage_push
    can_push_rhn_stage = @errata.can_push_rhn_stage?
    {
      :name => 'Push to RHN Staging',
      :status => (
                  if @errata.has_pushed_rhn_stage?
                    :ok
                  elsif can_push_rhn_stage
                    :wait
                  elsif !@errata.has_rhn_stage?
                    :minus
                  else
                    :block
                  end
                  ),
      :actions => [
                   last_push_link(RhnStagePushJob, @errata),
                   push_history_link(RhnStagePushJob, @errata),
                   if can_push_rhn_stage
                     workflow_action_link("Push Now", { :action => 'push_errata', :stage=>1, :controller => 'push', :id => @errata})
                   end,
                  ],
      :info => [
                push_info_list(@errata, :rhn_stage),
               ],
    }

  end

  def ftp_push
    can_push_ftp = @errata.can_push_ftp?
    {
      :name => 'Push to FTP',
      :status => if @errata.pushed?
                   :ok
                 elsif can_push_ftp
                   :wait
                 elsif !@errata.has_ftp?
                   :minus
                 else
                   :block
                 end,
      :actions => [
                   last_push_link(FtpPushJob, @errata),
                   push_history_link(FtpPushJob, @errata),
                   if can_push_ftp
                     workflow_action_link("Push Now", { :action => 'push_errata', :controller => 'push', :id => @errata})
                   end
                  ],
      :info => [
                push_info_list(@errata, :ftp),
               ],
    }

  end

  def no_ftp_push
    {
      :name => "(No FTP push)",
      :status => :minus,
      :actions => [],
      :info => [
                "#{@errata.product.short_name} doesn't get pushed to FTP"
               ],
    }
  end

  def altsrc_push
    can_push_altsrc = @errata.can_push_altsrc?
    {
      :name => 'Push to CentOS git',
      :status => if @errata.has_pushed_altsrc?
                   :ok
                 elsif can_push_altsrc
                   :wait
                 elsif !@errata.has_altsrc?
                   :minus
                 else
                   :block
                 end,
      :actions => [
                   last_push_link(AltsrcPushJob, @errata),
                   push_history_link(AltsrcPushJob, @errata),
                   if can_push_altsrc
                     workflow_action_link("Push Now", { :action => 'push_errata', :controller => 'push', :id => @errata})
                   end
                  ],
      :info => [
                push_info_list(@errata, :altsrc),
               ],
    }

  end

  def live_push
    can_push_rhn_live = @errata.can_push_rhn_live?
    {
      :name => 'Push to RHN Live',
      :status => if @errata.has_pushed_rhn_live?
                   :ok
                 elsif can_push_rhn_live
                   :wait
                 elsif !@errata.has_rhn_live?
                   :minus
                 else
                   :block
                 end,
      :actions => [
                   last_push_link(RhnLivePushJob, @errata),
                   last_prepush_link(RhnLivePushJob, @errata),
                   push_history_link(RhnLivePushJob, @errata),
                   if can_push_rhn_live
                     workflow_action_link("Push Now", { :action => 'push_errata', :controller => 'push', :id => @errata})
                   end
                  ],
      :info => [
                push_info_list(@errata, :rhn_live),
               ],
    }

  end

  def set_metadata_cdn_repos
    supports_docker = @errata.has_docker?
    current_repos = @errata.docker_metadata_repo_list.try(:get_cdn_repos) || []
    {
      :name => 'CDN Repos for Advisory Metadata',
      :status => if supports_docker
                   current_repos.any? ? :ok : :wait
                 else
                   :minus
                 end,
      :actions => [
                    if supports_docker && @errata.status_is?(:NEW_FILES)
                      workflow_action_link('Set', {:action => :docker_cdn_repos, :id => @errata })
                    end
                  ],
      :info => if supports_docker
                 [
                   ("(Can update only when status is NEW_FILES)" unless @errata.status_is?(:NEW_FILES)),
                   current_repos.any? ?
                     "Current: #{current_repos.map(&:name).join(', ')}" :
                     "Not set"
                 ]
               else
                 [ "This advisory does not contain docker images" ]
               end
    }
  end

  def cdn_docker_push
    can_push_cdn_docker = @errata.can_push_cdn_docker?
    {
      :name => 'Push to CDN Docker',
      :status => (
                  if @errata.has_pushed_cdn_docker?
                    :ok
                  elsif can_push_cdn_docker
                    :wait
                  elsif !@errata.has_cdn_docker?
                    :minus
                  else
                    :block
                  end
                  ),
      :actions => [
                   last_push_link(CdnDockerPushJob, @errata),
                   push_history_link(CdnDockerPushJob, @errata),
                   if can_push_cdn_docker
                     workflow_action_link('Push Now', { :action => 'push_errata', :controller => 'push', :id => @errata})
                   end,
                  ],
      :info => [
                push_info_list(@errata, :cdn_docker),
               ],
    }

  end

  def cdn_docker_stage_push
    can_push_cdn_docker_stage = @errata.can_push_cdn_docker_stage?
    {
      :name => 'Push to CDN Docker Staging',
      :status => (
                  if @errata.has_pushed_cdn_docker_stage?
                    :ok
                  elsif can_push_cdn_docker_stage
                    :wait
                  elsif !@errata.has_cdn_docker_stage?
                    :minus
                  else
                    :block
                  end
                  ),
      :actions => [
                   last_push_link(CdnDockerStagePushJob, @errata),
                   push_history_link(CdnDockerStagePushJob, @errata),
                   if can_push_cdn_docker_stage
                     workflow_action_link('Push Now', { :action => 'push_errata', :stage=>1, :controller => 'push', :id => @errata})
                   end,
                  ],
      :info => [
                push_info_list(@errata, :cdn_docker_stage),
               ],
    }

  end

  def cdn_stage_push
    can_push_cdn_stage = @errata.can_push_cdn_stage?
    {
      :name => 'Push to CDN Staging',
      :status => (
                  if @errata.has_pushed_cdn_stage?
                    :ok
                  elsif can_push_cdn_stage
                    :wait
                  elsif !@errata.has_cdn_stage?
                    :minus
                  else
                    :block
                  end
                  ),
      :actions => [
                   last_push_link(CdnStagePushJob, @errata),
                   push_history_link(CdnStagePushJob, @errata),
                   if can_push_cdn_stage
                     workflow_action_link('Push Now', { :action => 'push_errata', :stage=>1, :controller => 'push', :id => @errata})
                   end,
                  ],
      :info => [
                push_info_list(@errata, :cdn_stage),
               ],
    }

  end

  def cdn_push
    push_target = @errata.supports_rhn_live? ? :cdn_if_live_push_succeeds : :cdn
    can_push_to_push_target = @errata.can_push_to?(push_target)
    {
      :name => 'Push to CDN',
      :status => if @errata.has_pushed_cdn_live?
                   :ok
                 elsif can_push_to_push_target
                   :wait
                 elsif !@errata.has_cdn?
                   :minus
                 else
                   :block
                 end,
      :actions => [
                   last_push_link(CdnPushJob, @errata),
                   last_prepush_link(CdnPushJob, @errata),
                   push_history_link(CdnPushJob, @errata),
                   if can_push_to_push_target
                     workflow_action_link('Push Now', { :action => 'push_errata', :controller => 'push', :id => @errata})
                   end
                  ],
      :info => [
                push_info_list(@errata, :cdn, push_target),
               ],
    }

  end

  def mail_announcement
    {
      :name => 'Announcement Sent',
      :status => if @errata.mailed?
                   :ok
                 elsif @errata.shipped_live?
                   :wait
                 else
                   :block
                 end,
      :actions => [],
      :info => [
                ""
               ],
    }

  end

  def ccat_verify
    test_types = ExternalTestType.find_by_name!('ccat').with_related_types
    passed = @errata.external_test_runs_passed_for?('ccat')
    tests = @errata.external_test_runs_for(test_types).active
    failed = tests.where(:status => ExternalTestRun.failed_statuses).any?
    pending = tests.where(:status => 'PENDING').any?
    summary = 'Test results not available'
    status = :wait

    show_link = tests.any?

    if !@errata.shipped_live?
      summary = 'Advisory is not shipped'
      status = :block
    elsif pending
      summary = 'Testing in progress'
    elsif passed
      summary = 'CDN content has been verified'
      status = :ok
    elsif failed
      summary = 'There are CDN content verification problems'
      status = :block
    end

    {
      :name => "Verify CDN Content",
      :status => status,
      :actions => [
        (workflow_action_link("View CCAT tests",
                              { :controller => :external_tests, :action => :list,
                                :id => @errata.id, :test_type => :ccat } ) if show_link),
      ].compact,
      :info => [
        summary,
      ],
    }
  end

  def close_advisory
    {
      :name => "Close Advisory",
      :status => if @errata.closed?
                   :ok
                 else
                   :wait
                 end,
      :actions => [
                   workflow_action_link((@errata.closed? ? 'Reopen' : 'Close'), {:action=>'close', :id=>@errata}),
                  ],
      :info => [
               ],
    }

  end
end
