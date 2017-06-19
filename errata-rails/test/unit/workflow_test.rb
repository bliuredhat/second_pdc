require 'test_helper'

class WorkflowTest < ActionController::TestCase
  include ErrataHelper
  include WorkflowHelper
  include ActionView::Helpers
  include ActionDispatch::Routing
  include Rails.application.routes.url_helpers
  include ApplicationHelper

  setup do
    # Various workflow steps would send qpid messages.
    # Make it do nothing
    MessageBus::SendMessageJob.any_instance.stubs(:perform)
  end

  def view_renderer(*args)
    # This allows template rendering in workflow_step_helper
    # (called by get_steps) as we're not in a controller
    vr = ActionView::Renderer.new(nil)
    vr.stubs(:render_partial).returns('')
    vr
  end

  test 'typical steps' do
    assert_steps Errata.find(16374), devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - Request QA - Current state: PUSH READY
      OK - Sign Advisory - All files signed
      OK - Push to CDN Staging - Last job (COMPLETE) Push History Push Now
      MINUS - (No FTP push) - RHCI doesn't get pushed to FTP
      WAIT - Push to CDN - Pre-push (COMPLETE) Push History Push Now
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos
  end

  test 'typical steps for an RHSA' do
    e = Errata.find(11149)
    e.product.update_attributes!(:text_only_advisories_require_dists => false)
    assert_steps Errata.find(11149), devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 3 edits
      WAIT - Request QA - Move to QE - RPMDiff is not required Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
      OK - RHN Channels/CDN Repos - Set - RHN Channels or CDN Repos not required
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      BLOCK - Push to RHN Staging - State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Product Security Approval - State invalid. Must be one of: QE, REL_PREP, PUSH_READY
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - JBEWS doesn't get pushed to FTP
      BLOCK - Announcement Sent
      WAIT - Close Advisory - Close
    eos
  end

  test 'the advisory with only non-RPM files' do
    # note that, after bug 1135967, it's now detected that RHN stage
    # and live pushes are not applicable for this advisory, since
    # non-RPMs are not shipped.  In practice, perhaps it doesn't make
    # sense to allow this kind of advisory to exist.
    assert_steps Errata.find(16397), devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added (4 build mappings)
      BLOCK - Add/Update File Attributes - Edit files - 0 files with attributes 3 files are missing attributes
      BLOCK - Request QA - Move to QE - Builds added RPMDiff is not required Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Must set attributes on non-RPM files Current state: NEW FILES
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      OK - Sign Advisory - All files signed
      MINUS - Push to RHN Staging - Rhn Stage is not supported by the packages in this advisory
      MINUS - Push to RHN Live - Rhn Live is not supported by the packages in this advisory
      MINUS - Push to FTP - There are no packages available to push to ftp
      WAIT - Close Advisory - Close
    eos
  end

  test 'RHN staging without push delay' do
    # (Some assertions in this test assume that TPS CDN is disabled)
    Settings.stubs(:enable_tps_cdn).returns(false)

    errata = Errata.find(11118)
    user = admin_user

    # moving back to NEW_FILES invalidates any earlier RHN stage push job
    past = 30.minutes.ago
    Time.stubs(:now => past)
    errata.change_state!('NEW_FILES', user)
    Time.stubs(:now => past + 5.seconds)
    errata.change_state!('QE', user)
    Time.stubs(:now => past + 15.seconds)

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 2 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 1 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 0
      OK - TPS Tests - View - GOOD: 9
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: QE
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      WAIT - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # RHN stage push job should cause notices without any delay, and RHNQA tests show up
    delayed_jobs = capture_delayed_jobs do
      do_push_jobs errata, RhnStagePushJob, user
    end
    # There is no delay on stage push
    refute_includes(delayed_jobs.map(&:method), :update_attribute)

    errata.reload

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 2 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 1 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 0
      OK - TPS Tests - View - GOOD: 9
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: QE
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      BLOCK - RHNQA TPS Tests - View - NOT_STARTED: 9
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos
  end

  # Bug 1069973
  test 'CDN push OK' do
    errata = Errata.find(16374)
    user = releng_user

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - Request QA - Current state: PUSH READY
      OK - Sign Advisory - All files signed
      OK - Push to CDN Staging - Last job (COMPLETE) Push History Push Now
      MINUS - (No FTP push) - RHCI doesn't get pushed to FTP
      WAIT - Push to CDN - Pre-push (COMPLETE) Push History Push Now
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    force_sync_delayed_jobs do
      do_push_jobs errata, CdnPushJob, user
    end

    errata.reload

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - 0 edits Can't edit in status SHIPPED_LIVE
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - Request QA - Current state: SHIPPED LIVE
      OK - Sign Advisory - All files signed
      OK - Push to CDN Staging - Last job (COMPLETE) Push History Push Now
      MINUS - (No FTP push) - RHCI doesn't get pushed to FTP
      OK - Push to CDN - Last job (COMPLETE) Pre-push (COMPLETE) Push History Push Now
      WAIT - Verify CDN Content - Test results not available
      WAIT - Close Advisory - Close
    eos
  end

  # Bug 1071849
  test 'CDN and RHN show as pushable together' do
    errata = Errata.find(10836)
    user = admin_user

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 6 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      OK - TPS Tests - View - GOOD: 9
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: PUSH READY
      WAIT - RPMDiff Review - Review Waivers - Waivers: 1 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      OK - RHNQA TPS Tests - View - GOOD: 9
      WAIT - Push to RHN Live - Push Now
      WAIT - Push to FTP - Push Now
      WAIT - Push to CDN - Push Now
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      OK - Push to CentOS git - Last job (COMPLETE) Push History Push Now
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos
  end

  test 'rpmdiff waivers' do
    errata = Errata.find(10808)
    user = admin_user

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      BLOCK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 1 Pending 0 Waived: 0
      BLOCK - Request QA - Move to QE - Builds added No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Must complete RPMDiff Current state: NEW FILES
      WAIT - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      WAIT - Sign Advisory - Request Signatures Refresh Signature State
      BLOCK - Push to RHN Staging - Packages are not signed
      State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - RHEL-EXTRAS doesn't get pushed to FTP
      WAIT - Close Advisory - Close
    eos

    count = 0
    errata.rpmdiff_runs.map(&:rpmdiff_results).map(&:waivable).flatten.each do |result|
      result.rpmdiff_waivers.create!(:user => User.first, :description => 'test waive', :old_result => result.score)
      result.update_attribute(:score, RpmdiffScore::WAIVED)
      count += 1
    end
    assert_equal 3, count

    errata.reload

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      WAIT - Request QA - Move to QE - Builds added RPMDiff Complete No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
      WAIT - RPMDiff Review - Review Waivers - Waivers: 3 Approved Waivers: 0
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      WAIT - Sign Advisory - Request Signatures Refresh Signature State
      BLOCK - Push to RHN Staging - Packages are not signed
      State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - RHEL-EXTRAS doesn't get pushed to FTP
      WAIT - Close Advisory - Close
    eos

    # check what happens now if the rpmdiff review becomes mandatory
    errata.product.update_attribute(:state_machine_rule_set_id, 5)
    errata.reload

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      WAIT - Request QA - Move to QE - Builds added RPMDiff Complete No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
      BLOCK - RPMDiff Review - Review Waivers - Waivers: 3 Approved Waivers: 0
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      WAIT - Sign Advisory - Request Signatures Refresh Signature State
      BLOCK - Push to RHN Staging - Packages are not signed
      State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - RHEL-EXTRAS doesn't get pushed to FTP
      WAIT - Close Advisory - Close
    eos

    errata.rpmdiff_runs.map(&:rpmdiff_results).flatten.map(&:rpmdiff_waivers).flatten.each do |w|
      w.ack!(:user => qa_user)
    end

    errata.reload

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      WAIT - Request QA - Move to QE - Builds added RPMDiff Complete No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
      OK - RPMDiff Review - Review Waivers - Waivers: 3 Approved Waivers: 3
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      WAIT - Sign Advisory - Request Signatures Refresh Signature State
      BLOCK - Push to RHN Staging - Packages are not signed
      State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - RHEL-EXTRAS doesn't get pushed to FTP
      WAIT - Close Advisory - Close
    eos
  end

  def text_only_advisory_step_test(errata, user, expected_text)
    assert_steps errata, user, expected_text,
                 :select => lambda{|line| line =~ /RHN Channels\/CDN Repos/}
  end

  test 'text-only advisories w/wo dists' do
    check_workflow = lambda do |e, require_dists, expected_dists, push_types, expected_message|
      e.expects(:text_only?).at_least_once.returns(true)
      e.product.stubs(:text_only_advisories_require_dists?).returns(require_dists)
      e.expects(:supported_push_types).at_least_once.returns(push_types)
      e.stubs(:text_only_channel_list => TextOnlyChannelList.new(:errata => e))
      expected_dists.any? ?
        e.text_only_channel_list.stubs(:get_all_channel_and_cdn_repos).returns(expected_dists) :
        []

      text_only_advisory_step_test e, releng_user, expected_message
    end

    errata = Errata.find 16654
    expected_dists= errata.active_channels_and_repos_for_available_product_versions
    supported_push_types = errata.supported_push_types
    expected_message_1 = 'WAIT - RHN Channels/CDN Repos - Set - Must set at least one RHN Channel or CDN Repo'
    expected_message_2 = 'OK - RHN Channels/CDN Repos - Set - RHN Channels or CDN Repos not required'
    expected_message_3 = 'WAIT - RHN Channels/CDN Repos - Set - None of the selected RHN Channels or CDN Repos have product versions with live push targets enabled.'
    expected_message_4 = "OK - RHN Channels/CDN Repos - Set - Current: #{expected_dists.map(&:name).join(', ')}"

    [
      [true, expected_dists, supported_push_types, expected_message_4],
      [true, expected_dists, [], expected_message_3],
      [true, [], supported_push_types, expected_message_1],
      [true, [], [], expected_message_1],
      # Let it still be able to set dists when product doesn't require dists
      # for text-only advisories
      [false, expected_dists, supported_push_types, expected_message_4],
      [false, expected_dists, [], expected_message_4],
      [false, [], [], expected_message_2],
      [false, [], supported_push_types, expected_message_2],
    ].each do |require_dists, dists, push_types, message|
      check_workflow.call(errata, require_dists, dists, push_types, message)
    end
  end

  test 'prevents setting channels/repos for text only advisory' do
    rhba_async.expects(:supported_push_types).at_least_once.returns([:cdn_live])
    rhba_async.expects(:text_only?).at_least_once.returns(true)
    rhba_async.stubs(:text_only_channel_list => TextOnlyChannelList.new(:errata => rhba_async))
    rhba_async.text_only_channel_list.stubs(:get_all_channel_and_cdn_repos).
      returns([CdnRepo.first])
    assert rhba_async.product.text_only_advisories_require_dists?

    assert_steps rhba_async, releng_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Request QA - Move to QE - Builds added RPMDiff is not required No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
      WAIT - RHN Channels/CDN Repos - Set - None of the selected RHN Channels or CDN Repos have product versions with live push targets enabled.
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      BLOCK - Push to FTP - This errata is not signed
      WAIT - Close Advisory - Close
    eos
  end

  test 'prevent text only advisory changing to REL_PREP without channel or repo' do
    # Text-only RHSA without dists
    e = qe_text_only_rhsa_without_dists
    assert e.text_only_channel_list.get_all_channel_and_cdn_repos.empty?

    # One thing noticed here is
    # 'OK - Push to RHN Staging - Must set at least one RHN Channel or CDN repo'
    # This is because we've mocked rhnqa? => true to pass RhnStageGuard. It could
    # happen in reality if dist is removed when respins.
    # However workflow shows OK with blocker message which is odd.
    assert_steps e, releng_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 6 edits
      OK - Request QA - Current state: QE
      WAIT - RHN Channels/CDN Repos - Set - Must set at least one RHN Channel or CDN Repo
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - Must set at least one RHN Channel or CDN repo
      OK - Product Security Approval - Disapprove - Approved
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - JBEM doesn't get pushed to FTP
      BLOCK - Announcement Sent
      WAIT - Close Advisory - Close
    eos

    # Disallow transitioning from QE to REL_PREP
    error = assert_raises(ActiveRecord::RecordInvalid) do
      e.change_state!(State::REL_PREP, admin_user)
    end

    assert_match(/Errata Must set at least one RHN Channel or CDN repo/, error.message)

    # Add cdn_repo and try again
    e.text_only_channel_list.channel_list = 'jb-middleware'
    e.text_only_channel_list.save!
    e.reload

    assert_steps e, releng_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 6 edits
      OK - Request QA - Current state: QE
      OK - RHN Channels/CDN Repos - Set - Current: jb-middleware
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - Push Now
      OK - Product Security Approval - Disapprove - Approved
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - JBEM doesn't get pushed to FTP
      BLOCK - Announcement Sent
      WAIT - Close Advisory - Close
    eos

    e.change_state!(State::REL_PREP, admin_user)
  end

  test 'block text-only advisory without dists transitioning from REL_PREP to PUSH_READY' do
    # Text-only RHSA without dists
    e = rel_prep_text_only_rhsa_without_dists
    assert_equal State::REL_PREP, e.status
    assert e.text_only_channel_list.get_all_channel_and_cdn_repos.empty?

    # Disallow transitioning from REL_PREP to PUSH_READY
    error = assert_raises(ActiveRecord::RecordInvalid) do
      e.change_state!(State::PUSH_READY, admin_user)
    end
    assert_match(/Errata Must set at least one RHN Channel or CDN repo/, error.message)

    assert_steps e, releng_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 6 edits
      OK - Request QA - Current state: REL PREP
      WAIT - RHN Channels/CDN Repos - Set - Must set at least one RHN Channel or CDN Repo
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - Must set at least one RHN Channel or CDN repo
      OK - Product Security Approval - Disapprove - Approved
      BLOCK - Push to RHN Live - State REL_PREP invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - (No FTP push) - JBEM doesn't get pushed to FTP
      BLOCK - Announcement Sent
      WAIT - Close Advisory - Close
    eos

    # Add channel and try again
    e.text_only_channel_list.channel_list = 'jb-middleware'
    e.text_only_channel_list.save!
    e.reload

    e.change_state!(State::PUSH_READY, admin_user)
  end

  test 'push to CDN displays appropriately when no active CDN repos' do
    errata = Errata.find(19028)

    assert_steps errata, admin_user, <<-'eos'.strip_heredoc.strip, :select => lambda{|step| step =~ /Push/}
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      WAIT - Push to RHN Live - Pre-push (COMPLETE) Push History Push Now
      WAIT - Push to FTP - Push Now
      MINUS - Push to CDN - There are no CDN Repos defined for products in &#x27;RHSA-2014:19028-01&#x27;
    eos
  end

  def push_steps_test(errata_id, expected)
    assert_steps Errata.find(errata_id), admin_user, expected.strip_heredoc.strip, :select => lambda{|step| step =~ /Push/}
  end

  test 'pushes OK when ready for live push and rhn restricted' do
    # note: not sure why push to CDN staging is not necessary before
    # pushing to CDN live
    push_steps_test 19030, <<-'eos'
      OK - Push to RHN Staging - Rhn Stage is not supported by the packages in this advisory
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      MINUS - Push to RHN Live - Rhn Live is not supported by the packages in this advisory
      WAIT - Push to FTP - Push Now
      WAIT - Push to CDN - Push Now
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      WAIT - Push to CentOS git - Push Now
    eos
  end

  test 'pushes OK when pushed live to CDN only, rhn restricted' do
    e = Errata.find(19030)
    do_push_jobs e, CdnPushJob, releng_user

    push_steps_test e.id, <<-'eos'
      OK - Push to RHN Staging - Rhn Stage is not supported by the packages in this advisory
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      MINUS - Push to RHN Live - Rhn Live is not supported by the packages in this advisory
      WAIT - Push to FTP - Push Now
      OK - Push to CDN - Last job (COMPLETE) Push History Push Now
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      WAIT - Push to CentOS git - Push Now
    eos
  end

  test 'pushes OK when ready for stage push and rhn restricted' do
    push_steps_test 19031, <<-'eos'
      MINUS - Push to RHN Staging - Rhn Stage is not supported by the packages in this advisory
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      MINUS - Push to RHN Live - Rhn Live is not supported by the packages in this advisory
      BLOCK - Push to FTP - This errata cannot be pushed to CDN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to CDN Live, thus may not be pushed to git
    eos
  end

  test 'pushes applicable detection does not depend on errata_files' do
    # This simulates the case where current_files for an advisory are
    # not (yet?) populated.
    e = Errata.find(19031)
    e.current_files.each(&:destroy)

    push_steps_test e.id, <<-'eos'
      MINUS - Push to RHN Staging - Rhn Stage is not supported by the packages in this advisory
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      MINUS - Push to RHN Live - Rhn Live is not supported by the packages in this advisory
      BLOCK - Push to FTP - This errata cannot be pushed to CDN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to CDN Live, thus may not be pushed to git
    eos
  end

  test 'pushes OK for advisory with non-RPMs only' do
    # This advisory has:
    # - RPM files
    # - non-RPM files
    # - non-RPM product listings for both CDN and RHN
    # Ditch the non-RPM files before the test and verify that
    # RHN, CDN pushes are still considered applicable.

    e = Errata.find(19029)
    e.build_mappings.for_rpms.each(&:obsolete!)

    push_steps_test e.id, <<-'eos'
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      OK - Push to CDN Staging - Last job (COMPLETE) Push History Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      WAIT - Push to RHN Live - Pre-push (FAILED) Push History Push Now
      MINUS - Push to FTP - There are no packages available to push to ftp
      WAIT - Push to CDN - Pre-push (COMPLETE) Push History Push Now
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      WAIT - Push to CentOS git - Push Now
    eos
  end

  test 'pushes OK when ready for live push and cdn restricted' do
    # Note in this fixture, I accidentally did a CDN staging push and
    # _then_ introduced package restriction, which is why the CDN
    # staging line appears both OK and "not supported".  I decided to
    # leave it in since we may as well test that it behaves sanely.
    # Also, remove one preexisting failed live job for this test.
    RhnLivePushJob.for_errata(19032).delete_all
    push_steps_test 19032, <<-'eos'
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      OK - Push to CDN Staging - Last job (COMPLETE) Push History - Cdn Stage is not supported by the packages in this advisory
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      WAIT - Push to RHN Live - Push Now
      WAIT - Push to FTP - Push Now
      MINUS - Push to CDN - Cdn is not supported by the packages in this advisory
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      WAIT - Push to CentOS git - Push Now
    eos
  end

  test 'pushes OK when ready for stage push and cdn restricted' do
    push_steps_test 19033, <<-'eos'
      WAIT - Push to RHN Staging - Push Now
      MINUS - Push to CDN Staging - Cdn Stage is not supported by the packages in this advisory
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      MINUS - Push to CDN - Cdn is not supported by the packages in this advisory
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
    eos
  end

  test 'block the tps and rhnqa tps test stage if no tps is scheduled' do
    errata = Errata.find(11118)
    user = admin_user

    errata.change_state!('QE', user)

    assert_steps errata, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 2 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 1 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 0
      OK - TPS Tests - View - GOOD: 9
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: QE
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      OK - RHNQA TPS Tests - View - GOOD: 9
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # Delete all the tps test jobs
    # TPS TEST, RHN & CDN Push and RHNQA TPS TEST should be blocked.
    errata.tps_run.tps_jobs.delete_all

    assert_steps errata.reload, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 2 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 1 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 0
      BLOCK - TPS Tests - View - No TPS test is scheduled.
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: QE
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Last job (COMPLETE) Push History - TPS testing incomplete
      BLOCK - Push to CDN Staging - TPS testing incomplete
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      BLOCK - RHNQA TPS Tests - View - TPS testing incomplete
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # Delete all rhnqa tps jobs
    # RHNQA TPS TEST error message should change
    errata.tps_run.rhnqa_jobs.delete_all

    assert_steps errata.reload, user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 2 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 1 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 0
      BLOCK - TPS Tests - View - No TPS test is scheduled.
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: QE
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Last job (COMPLETE) Push History - TPS testing incomplete
      BLOCK - Push to CDN Staging - TPS testing incomplete
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      BLOCK - RHNQA TPS Tests - View - No RHNQA TPS test is scheduled.
      BLOCK - Push to RHN Live - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    errors = assert_raises(ActiveRecord::RecordInvalid) do
      errata.change_state!('REL_PREP', user)
    end

    assert_equal "Validation failed: Errata Must complete TPS, Errata Must complete TPS RHNQA, Errata Staging push jobs not complete", errors.message

  end

  test 'advisory needs attributes on non-RPM files' do
    e = Errata.find(16396)

    initial_steps = <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Add/Update Brew Builds - Edit builds Reload 1 build with missing current files records - 1 build added (3 build mappings)
      BLOCK - Add/Update File Attributes - Edit files - 0 files with attributes 3 files are missing attributes
    eos

    assert_steps e, devel_user, initial_steps, :count => 3

    save_partial_meta = lambda{|meta|
      meta.title = "title for file #{meta.brew_file_id}"
      meta.save!
    }

    rank = 0
    save_complete_meta = lambda{|meta|
      meta.title = "title for file #{meta.brew_file_id}"
      meta.rank = (rank += 1)
      meta.save!
    }

    # adding some partial meta doesn't make a difference
    BrewFileMeta.find_or_init_for_advisory(e).first.tap(&save_partial_meta)
    e.reload

    assert_steps e, devel_user, initial_steps, :count => 3

    # adding one complete meta changes the text a bit
    BrewFileMeta.find_or_init_for_advisory(e).first.tap(&save_complete_meta)
    e.reload

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip, :count => 3
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Add/Update Brew Builds - Edit builds Reload 1 build with missing current files records - 1 build added (3 build mappings)
      BLOCK - Add/Update File Attributes - Edit files - 1 file with attributes 2 files are missing attributes
    eos

    # setting all the meta should unblock
    BrewFileMeta.find_or_init_for_advisory(e).each(&save_complete_meta)

     assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip, :count => 3
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Add/Update Brew Builds - Edit builds Reload 1 build with missing current files records - 1 build added (3 build mappings)
      OK - Add/Update File Attributes - Edit files - 3 files with attributes
    eos
  end

  test "POST_PUSH_FAILED push job is considered complete" do
    e = Errata.find(19435)

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - 7 edits Can't edit in status SHIPPED_LIVE
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 2 builds added
      OK - RPMDiff Tests - View - Passed: 1 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      OK - Request QA - Current state: SHIPPED LIVE Closed
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now - Push target is not supported by all variants
      BLOCK - Product Security Approval - State invalid. Must be one of: QE, REL_PREP, PUSH_READY
      OK - Push to RHN Live - Last job (POST_PUSH_FAILED) Push History Push Now - Push target is not supported by all variants
      OK - Push to FTP - Last job (COMPLETE) Push History Push Now
      OK - Push to CDN - Last job (COMPLETE) Push History Push Now - Push target is not supported by all variants
      WAIT - Push to CentOS git - Push Now
      WAIT - Verify CDN Content - View CCAT tests - Testing in progress
      OK - Announcement Sent
      OK - Close Advisory - Reopen
    eos
  end

  # Bug 1147232
  test "block altsrc push for text only advisory with altsrc support" do

    e = Errata.find 16616
    assert e.text_only?
    assert e.supports_altsrc?

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Request QA - Current state: PUSH READY
      OK - RHN Channels/CDN Repos - Set - Current: rhel-i386-server-6, rhel-x86_64-server-6
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - Last job (COMPLETE) Push History Push Now
      OK - Push to CDN Staging - Last job (COMPLETE) Push History Push Now
      WAIT - Push to RHN Live - Push Now
      MINUS - Push to FTP - There are no packages available to push to ftp
      WAIT - Push to CDN - Push Now
      MINUS - Push to CentOS git - There are no packages available to push to git
      WAIT - Close Advisory - Close
    eos

    e.text_only_channel_list.channel_list = ""
    e.text_only_channel_list.cdn_repo_list = ""
    e.text_only_channel_list.save!
    e = Errata.find 16616
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Request QA - Current state: PUSH READY
      WAIT - RHN Channels/CDN Repos - Set - Must set at least one RHN Channel or CDN Repo
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - Last job (COMPLETE) Push History - Must set at least one RHN Channel or CDN repo
      OK - Push to CDN Staging - Last job (COMPLETE) Push History - Must set at least one RHN Channel or CDN repo
      BLOCK - Push to RHN Live - Must set at least one RHN Channel or CDN repo
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CentOS git - There are no packages available to push to git
      WAIT - Close Advisory - Close
    eos
  end

  # Bug 1203905
  test 'push jobs display OK while IN_PUSH' do
    e = Errata.find(19032)

    e.change_state!('IN_PUSH', admin_user)

    assert_steps e, admin_user, <<-'eos'.strip_heredoc.strip, :select => lambda{|step| step =~ /Push/}
      OK - Push to RHN Staging - Last job (COMPLETE) Push History - State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      OK - Push to CDN Staging - Last job (COMPLETE) Push History - Cdn Stage is not supported by the packages in this advisory
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      OK - Push to RHN Live - Last job (POST_PUSH_PROCESSING) Push History Push Now
      WAIT - Push to FTP - Push Now
      MINUS - Push to CDN - Cdn is not supported by the packages in this advisory
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      WAIT - Push to CentOS git - Push Now
    eos
  end

  def product_security_step_test(errata, user, expected_text)
    assert_steps errata, user, expected_text, :select => lambda{|line| line =~ /Product Security Approval/}
  end

  test 'PST Request Approval offered on unrequested rel-prep RHSA' do
    product_security_step_test(
      rel_prep_unrequested_rhsa,
      devel_user,
      'WAIT - Product Security Approval - Request Approval - Not requested')
  end

  test 'no PST action offered to devel when waiting for approval' do
    product_security_step_test(
      rel_prep_requested_rhsa,
      devel_user,
      'WAIT - Product Security Approval - Requested')
  end

  test 'PST Approve offered to secalert when waiting for approval' do
    product_security_step_test(
      rel_prep_requested_rhsa,
      secalert_user,
      'WAIT - Product Security Approval - Approve - Requested')
  end

  test 'PST Disapprove offered to devel when approved' do
    product_security_step_test(
      rel_prep_approved_rhsa,
      devel_user,
      'OK - Product Security Approval - Disapprove - Approved')
  end

  test 'PST approval requires correct state' do
    product_security_step_test(
      new_files_rhsa,
      devel_user,
      'BLOCK - Product Security Approval - State invalid. Must be one of: QE, REL_PREP, PUSH_READY')
  end

  test 'no PST approval step for non-RHSA' do
    product_security_step_test(rel_prep_rhba, secalert_user, '')
  end

  # Bug 1101806
  test "block advisory if no rpmdiff job is scheduled" do
    errata = Errata.find(7517)

    # Should have this:
    # BLOCK - RPMDiff Tests - View - RPMDiff tests are not scheduled
    assert_steps errata, devel_user, <<-'eos'.strip_heredoc.strip, :count => 4
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 4 builds added (5 build mappings)
      BLOCK - RPMDiff Tests - View - RPMDiff tests are not scheduled
      BLOCK - Request QA - Move to QE - Builds added No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Must complete RPMDiff Current state: NEW FILES
    eos

    RpmdiffRun.schedule_runs(errata)

    # Should have this:
    # BLOCK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 4 Waived: 0
    assert_steps errata, devel_user, <<-'eos'.strip_heredoc.strip, :count => 4
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 4 builds added (5 build mappings)
      BLOCK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 4 Waived: 0
      BLOCK - Request QA - Move to QE - Builds added No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Must complete RPMDiff Current state: NEW FILES
    eos

    pass_rpmdiff_runs(errata)

    # Should have this:
    # OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 4
    assert_steps errata, devel_user, <<-'eos'.strip_heredoc.strip, :count => 4
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 4 builds added (5 build mappings)
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 4
      WAIT - Request QA - Move to QE - Builds added RPMDiff Complete No non-RPM files in advisory Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
    eos
  end

  test 'block advisory in new_files state if missing product listing' do
    errata = Errata.find(7517)
    # Delete product listing cache for 2 mappings to manipulate the output
    errata.build_mappings.first(2).each do |et_map|
      pv = et_map.product_version
      bb = et_map.brew_build
      ProductListingCache.where(:product_version_id => pv, :brew_build_id => bb).delete_all
    end

    # Should have this:
    # WAIT - Add/Update Brew Builds - Edit builds Reload 2 missing product listings - 4 builds added
    assert_steps errata, devel_user, <<-'eos'.strip_heredoc.strip, :count => 2
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Add/Update Brew Builds - Edit builds Reload 2 missing product listings - 4 builds added (5 build mappings)
    eos

    # Don't allow to change to QE
    error = assert_raises(ActiveRecord::RecordInvalid) do
      errata.change_state!('QE', devel_user)
    end
    assert_match(/Validation failed: Errata Missing 2 product listings/, error.message)
  end

  test 'block advisory changing to QE state if missing current files' do
    errata = Errata.find(16396)
    assert errata.build_mappings.for_rpms.without_current_files.any?

    assert_steps errata, devel_user, <<-'eos'.strip_heredoc.strip, :count => 5
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Add/Update Brew Builds - Edit builds Reload 1 build with missing current files records - 1 build added (3 build mappings)
      BLOCK - Add/Update File Attributes - Edit files - 0 files with attributes 3 files are missing attributes
      BLOCK - RPMDiff Tests - View - RPMDiff tests are not scheduled
      BLOCK - Request QA - Move to QE - Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Missing current files records for 1 build Must complete RPMDiff Must set attributes on non-RPM files Current state: NEW FILES
    eos

    # Don't allow to change to QE
    error = assert_raises(ActiveRecord::RecordInvalid) do
      errata.change_state!('QE', devel_user)
    end
    assert_match(/Validation failed: Errata Missing current files records for 1 build/, error.message)
  end

  test 'ccat hidden when not applicable' do
    errata = ccat_not_applicable_errata

    # This advisory supports CDN and CCAT, but has no CDN content
    assert errata.requires_external_test?(:ccat)
    assert errata.supports_cdn?
    refute errata.has_cdn?

    assert_ccat_steps errata, devel_user, ''
  end

  test 'ccat hidden when too old' do
    errata = ccat_old_not_started_errata

    # This advisory supports CDN and CCAT, and has CDN content, but was shipped
    # too long ago to use CCAT
    assert errata.requires_external_test?(:ccat)
    assert errata.supports_cdn?
    assert errata.has_cdn?

    assert errata.current_state_index.updated_at < Settings.ccat_start_time

    assert_ccat_steps errata, devel_user, ''
  end

  test 'ccat shown for old errata if there are results' do
    errata = ccat_old_not_started_errata

    # Initially, CCAT not shown, since the advisory is too old
    assert_ccat_steps errata, devel_user, ''

    # Now if some result arrives, it will be shown
    errata.create_external_test_run_for('ccat', :status => 'PENDING')

    assert_ccat_steps(errata.reload, devel_user,
                      'WAIT - Verify CDN Content - View CCAT tests - Testing in progress')
  end

  test 'ccat shown for non-CDN errata if there are results' do
    errata = ccat_not_cdn_errata

    refute errata.supports_cdn?

    # Initially, CCAT not shown, since the advisory does not support CDN
    assert_ccat_steps errata, devel_user, ''

    # Now if some result arrives, it will be shown
    errata.create_external_test_run_for('ccat', :status => 'PENDING')

    assert_ccat_steps(errata.reload, devel_user,
                      'WAIT - Verify CDN Content - View CCAT tests - Testing in progress')
  end

  test 'ccat display when not yet SHIPPED_LIVE' do
    errata = ccat_not_shipped_errata

    # This advisory should do CCAT, but not yet because it's not yet shipped
    assert_equal 'NEW_FILES', errata.status

    assert_ccat_steps(errata, devel_user,
                      'BLOCK - Verify CDN Content - Advisory is not shipped')
  end

  test 'ccat display when not yet started' do
    errata = ccat_not_started_errata

    # This advisory should do CCAT, but no test runs exist yet
    refute errata.external_test_runs_for(:ccat).any?

    assert_ccat_steps(errata, devel_user,
                      'WAIT - Verify CDN Content - Test results not available')
  end

  test 'ccat display when failed' do
    errata = ccat_failed_errata

    assert_ccat_steps(errata, devel_user,
                      'BLOCK - Verify CDN Content - View CCAT tests - There are CDN content verification problems')
  end

  test 'ccat display when passed' do
    errata = ccat_passed_errata

    assert_ccat_steps(errata, devel_user,
                      'OK - Verify CDN Content - View CCAT tests - CDN content has been verified')
  end

  test 'ccat display when running' do
    errata = ccat_running_errata

    assert_ccat_steps(errata, devel_user,
                      'WAIT - Verify CDN Content - View CCAT tests - Testing in progress')
  end

  def do_push(klass, errata, user)
    # need to enable pub options here in order to create pub task
    job = klass.create!(:errata => errata, :pushed_by => user, :pub_options => {'push_files'=> true, 'push_metadata' => true})
    job.create_pub_task(Push::PubClient.get_connection)
    job.pub_success!
  end

  test "docker push workflow" do
    e = Errata.find(21101)

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      WAIT - CDN Repos for Advisory Metadata - Set - Not set
      BLOCK - Request QA - Move to QE - Advisory metadata CDN repos not selected Builds added RPMDiff is not required Attributes set on non-RPM files Advisory has bugs assigned All docker files are mapped to CDN repositories Current state: NEW FILES
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      OK - Sign Advisory - All files signed
      BLOCK - Push to CDN Staging - No metadata repositories selected
      BLOCK - Push to CDN Docker Staging - No metadata repositories selected
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - No metadata repositories selected
      BLOCK - Push to CDN Docker - No metadata repositories selected
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # Set docker metadata repos
    e.docker_metadata_repo_list = DockerMetadataRepoList.create(:errata => e)
    e.save!
    e.docker_metadata_repo_list.set_cdn_repos_by_id([21])
    e.docker_metadata_repo_list.save!
    e.reload

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      OK - CDN Repos for Advisory Metadata - Set - Current: rhel-6-server-optional-rpms__6Server__x86_64
      WAIT - Request QA - Move to QE - Builds added RPMDiff is not required Attributes set on non-RPM files Advisory metadata CDN repos selected Advisory has bugs assigned All docker files are mapped to CDN repositories Current state: NEW FILES
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      OK - Sign Advisory - All files signed
      BLOCK - Push to CDN Staging - State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to CDN Docker Staging - State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to CDN Docker - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    e.change_state!('QE', devel_user)
    e.reload

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-6-server-optional-rpms__6Server__x86_64
      OK - Request QA - Current state: QE
      WAIT - Docs Approval - View docs - Requested, not yet approved
      OK - Sign Advisory - All files signed
      WAIT - Push to CDN Staging - Push Now
      WAIT - Push to CDN Docker Staging - Push Now
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to CDN Docker - State QE invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    e.approve_docs!
    e.stubs(:stage_push_complete?).returns(true)

    e.change_state!('REL_PREP', qa_user)
    e.change_state!('PUSH_READY', admin_user)
    e.reload

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-6-server-optional-rpms__6Server__x86_64
      OK - Request QA - Current state: PUSH READY
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      WAIT - Push to CDN Staging - Push Now
      WAIT - Push to CDN Docker Staging - Push Now
      MINUS - Push to FTP - There are no packages available to push to ftp
      WAIT - Push to CDN - Push Now
      WAIT - Push to CDN Docker - Push Now
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # Delete the package mapping
    CdnRepoPackage.find(4).delete
    e.reload

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-6-server-optional-rpms__6Server__x86_64
      OK - Request QA - Current state: PUSH READY
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      MINUS - Push to CDN Staging - The following Docker builds are not mapped to any CDN repositories: rhel-server-docker-6.8-25
      MINUS - Push to CDN Docker Staging - The following Docker builds are not mapped to any CDN repositories: rhel-server-docker-6.8-25
      MINUS - Push to FTP - There are no packages available to push to ftp
      MINUS - Push to CDN - The following Docker builds are not mapped to any CDN repositories: rhel-server-docker-6.8-25
      MINUS - Push to CDN Docker - The following Docker builds are not mapped to any CDN repositories: rhel-server-docker-6.8-25
      WAIT - Close Advisory - Close
    eos
  end

  test "docker without push targets configured" do
    e = Errata.find(21100)
    assert e.has_docker?
    assert_equal 1, e.product_versions.count

    # Can push to cdn_docker
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-7-server-debug-rpms__7Server__x86_64, rhel-7-server-rpms__7Server__x86_64
      OK - Request QA - Current state: PUSH READY
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      MINUS - Push to FTP - There are no packages available to push to ftp
      WAIT - Push to CDN - Push Now
      WAIT - Push to CDN Docker - Push Now
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # This is the pv level push target
    apt = ActivePushTarget.find(1087)
    assert_equal :cdn_docker, apt.push_target.push_type
    assert_equal apt.product_version, e.product_versions.first

    # Delete the related variant push targets
    apt.variant_push_targets.delete_all
    e.reload

    # Now unable to push to cdn_docker
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-7-server-debug-rpms__7Server__x86_64, rhel-7-server-rpms__7Server__x86_64
      OK - Request QA - Current state: PUSH READY
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      MINUS - Push to FTP - There are no packages available to push to ftp
      MINUS - Push to CDN - Cdn Docker is not supported by the packages in this advisory
      MINUS - Push to CDN Docker - Cdn Docker is not supported by the packages in this advisory
      WAIT - Close Advisory - Close
    eos
  end

  test "cdn docker stage works even if cdn docker is disabled" do
    e = Errata.find(21101)

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - Edit builds - 1 build added
      WAIT - CDN Repos for Advisory Metadata - Set - Not set
      BLOCK - Request QA - Move to QE - Advisory metadata CDN repos not selected Builds added RPMDiff is not required Attributes set on non-RPM files Advisory has bugs assigned All docker files are mapped to CDN repositories Current state: NEW FILES
      WAIT - Docs Approval - View docs Request approval - Not currently requested
      OK - Sign Advisory - All files signed
      BLOCK - Push to CDN Staging - No metadata repositories selected
      BLOCK - Push to CDN Docker Staging - No metadata repositories selected
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - No metadata repositories selected
      BLOCK - Push to CDN Docker - No metadata repositories selected
      BLOCK - Verify CDN Content - Advisory is not shipped
      WAIT - Close Advisory - Close
    eos

    # Set docker metadata repos
    e.docker_metadata_repo_list = DockerMetadataRepoList.create(:errata => e)
    e.save!
    e.docker_metadata_repo_list.set_cdn_repos_by_id([21])
    e.docker_metadata_repo_list.save!
    e.change_state!('QE', devel_user)
    e.reload

    # This is the pv level push target
    apt = ActivePushTarget.find(1088)
    assert_equal :cdn_docker, apt.push_target.push_type
    assert_equal apt.product_version, e.product_versions.first

    # Delete the related variant push targets
    apt.variant_push_targets.delete_all
    e.reload
    e.approve_docs!
    e.stubs(:stage_push_complete?).returns(true)

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-6-server-optional-rpms__6Server__x86_64
      OK - Request QA - Current state: QE
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      WAIT - Push to CDN Staging - Push Now
      WAIT - Push to CDN Docker Staging - Push Now
      MINUS - Push to FTP - There are no packages available to push to ftp
      MINUS - Push to CDN - Cdn Docker is not supported by the packages in this advisory
      MINUS - Push to CDN Docker - Cdn Docker is not supported by the packages in this advisory
      WAIT - Close Advisory - Close
    eos

    # Remove the pv level push target
    apt.delete

    # Can't just reload as supported_push_targets are memoized
    e = Errata.find(21101)

    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - CDN Repos for Advisory Metadata - (Can update only when status is NEW_FILES) Current: rhel-6-server-optional-rpms__6Server__x86_64
      OK - Request QA - Current state: QE
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      WAIT - Push to CDN Staging - Push Now
      WAIT - Push to CDN Docker Staging - Push Now
      MINUS - Push to FTP - There are no packages available to push to ftp
      MINUS - Push to CDN - Advisory contains docker images but CDN docker push target is not enabled.
      WAIT - Close Advisory - Close
    eos
  end

  test "advisory with no bugs cannot move to QE" do
    e = Errata.find(16375)
    e.product.update_attributes!(:text_only_advisories_require_dists => false)
    assert e.bugs.none?
    assert e.jira_issues.none?

    # Advisory has no bugs, so can't be moved to QE
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      BLOCK - Request QA - Move to QE - RPMDiff is not required Advisory metadata CDN repos not required Advisory does not have docker files Advisory has no Bugzilla bugs or JIRA issues Current state: NEW FILES
      OK - RHN Channels/CDN Repos - Set - RHN Channels or CDN Repos not required
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      WAIT - Close Advisory - Close
    eos

    # Assign a bug to the advisory
    TestData.add_test_bug(e)
    assert e.reload.bugs.any?

    # The QE block has been lifted
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      WAIT - Request QA - Move to QE - RPMDiff is not required Advisory metadata CDN repos not required Advisory has bugs assigned Advisory does not have docker files Current state: NEW FILES
      OK - RHN Channels/CDN Repos - Set - RHN Channels or CDN Repos not required
      OK - Docs Approval - View docs - Approved
      OK - Push to RHN Staging - State invalid. Must be one of: QE, REL_PREP, PUSH_READY, SHIPPED_LIVE
      BLOCK - Push to RHN Live - State NEW_FILES invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      MINUS - Push to FTP - There are no packages available to push to ftp
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      WAIT - Close Advisory - Close
    eos
  end

  test "warning shown if not all variants support push target" do
    e = Errata.find(19463)
    variant = Variant.find_by_name('6Server')
    cdn = PushTarget.find_by_push_type(:cdn)
    assert e.variants.include? variant
    assert variant.push_targets.include? cdn

    # No warning shown, all push targets supported by all variants
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      BLOCK - External Tests - View Covscan - Passed or waived 0 of 1 current test runs.
      BLOCK - ABI Diff Tests - View - Passed: 0 Blocking: 0 Started:  0 Failed:  0
      OK - TPS Tests - View - GOOD: 15
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: REL PREP
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Push Now
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      OK - RHNQA TPS Tests - View - GOOD: 15
      OK - Product Security Approval - Disapprove - Approved
      BLOCK - Push to RHN Live - State REL_PREP invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      BLOCK - Announcement Sent
      WAIT - Close Advisory - Close
    eos

    # Delete the CDN variant push target
    variant_push_target = variant.variant_push_targets.where(:push_target_id => cdn).destroy_all
    e.reload

    # Warning now shown for CDN push target
    assert_steps e, devel_user, <<-'eos'.strip_heredoc.strip
      OK - Add/Update Advisory Details - Edit advisory - 0 edits
      OK - Add/Update Brew Builds - (Can update builds only when status is NEW_FILES) 1 build added
      OK - RPMDiff Tests - View - Passed: 0 Failed: 0 Needs Inspection: 0 Pending 0 Waived: 1
      BLOCK - External Tests - View Covscan - Passed or waived 0 of 1 current test runs.
      BLOCK - ABI Diff Tests - View - Passed: 0 Blocking: 0 Started:  0 Failed:  0
      OK - TPS Tests - View - GOOD: 15
      MINUS - CDN Repos for Advisory Metadata - This advisory does not contain docker images
      OK - Request QA - Current state: REL PREP
      OK - RPMDiff Review - Review Waivers - Waivers: 0 Approved Waivers: 0
      OK - Docs Approval - View docs - Approved
      OK - Sign Advisory - All files signed
      OK - Push to RHN Staging - Push Now
      WAIT - Push to CDN Staging - Push Now
      MINUS - Push to CDN Docker Staging - This advisory does not contain docker images
      OK - RHNQA TPS Tests - View - GOOD: 15
      OK - Product Security Approval - Disapprove - Approved
      BLOCK - Push to RHN Live - State REL_PREP invalid. Must be one of: PUSH_READY, IN_PUSH, SHIPPED_LIVE
      BLOCK - Push to FTP - This errata cannot be pushed to RHN Live, thus may not be pushed to FTP
      BLOCK - Push to CDN - This errata cannot be pushed to RHN Live, thus may not be pushed to CDN
      Push target is not supported by all variants
      MINUS - Push to CDN Docker - This advisory does not contain docker images
      BLOCK - Push to CentOS git - This errata cannot be pushed to RHN Live, thus may not be pushed to git
      BLOCK - Verify CDN Content - Advisory is not shipped
      BLOCK - Announcement Sent
      WAIT - Close Advisory - Close
    eos
  end

  def rhnqa_tps_jobs_step_test(errata, user, expected_text)
    assert_steps errata, user, expected_text, :select => lambda{|line| line =~ /RHNQA TPS Tests/}
  end

  def get_steps(errata, user)
    @errata = errata
    @user = user
    with_current_user(@user) do
      @errata.workflow_steps.inject(ActiveSupport::OrderedHash.new) do |out, step|
        out[step] = workflow_step_helper step
        out
      end
    end
  end

  def assert_steps(errata, user, text, opts = {})
    steps = get_steps(errata, user).values
    if c=opts[:count]
      steps = steps.take(c)
    end
    select = opts[:select] || lambda{|x| true}
    actual = steps.map{|s| step_to_text(s)}.select(&select).join("\n")
    assert_equal_or_diff text, actual, "Workflow steps not as expected:"
  end

  def assert_ccat_steps(errata, user, text, opts = {})
    opts = opts.merge(:select => lambda{ |text| text.include?('Verify CDN Content') })
    assert_steps(errata, user, text, opts)
  end

  # Converts a step description into a plaintext form similar as would be
  # displayed in the UI
  def step_to_text(step)
    [
      step[:status].to_s.upcase,
      step[:name],
      step[:actions].reject(&:blank?).join(' '),
      step[:info].reject(&:blank?).join(' ')
    ].map{|text| dumb_strip_html(text)} \
      .reject(&:blank?) \
      .join(' - ')
  end

  def dumb_strip_html(text)
    text.gsub(/<[^>]+>/, '').strip
  end

  def rel_prep_unrequested_rhsa
    Errata.find(11138)
  end

  def rel_prep_requested_rhsa
    Errata.find(11133)
  end

  def rel_prep_approved_rhsa
    Errata.find(19463)
  end

  def rel_prep_rhba
    Errata.find(11118)
  end

  def new_files_rhsa
    Errata.find(11149)
  end

  def qe_rhsa
    Errata.find(18894)
  end

  def rel_prep_text_only_rhsa_without_dists
    e = RHSA.find(11138)
    assert e.product.text_only_advisories_require_dists?
    assert e.text_only?
    e.text_only_channel_list.channel_list = ''
    e.text_only_channel_list.cdn_repo_list = ''
    e.text_only_channel_list.save!

    # Fail on RhnStageGuard if false
    e.stubs(:rhnqa?).returns(true)
    # Fail on SecurityApprovalGuard if false
    e.stubs(:security_approved?).returns(true)
    e.reload
  end

  def qe_text_only_rhsa_without_dists
    e = rel_prep_text_only_rhsa_without_dists
    e.change_state!(State::QE, admin_user)
    e
  end

  def ccat_not_applicable_errata
    Errata.find(20291)
  end

  def ccat_not_shipped_errata
    Errata.find(20836)
  end

  # For this errata, CCAT is not yet started, but is expected to happen
  def ccat_not_started_errata
    Errata.find(20044)
  end

  # For this errata, CCAT is not yet started, and is not expected to happen
  # because the advisory was shipped too long ago
  def ccat_old_not_started_errata
    Errata.find(11129)
  end

  # For this errata, CCAT is not yet started, and is not expected to happen
  # because the advisory is RHN-only
  def ccat_not_cdn_errata
    Errata.find(18917)
  end

  def ccat_failed_errata
    Errata.find(13147)
  end

  def ccat_passed_errata
    Errata.find(18905)
  end

  def ccat_running_errata
    Errata.find(19435)
  end
end
