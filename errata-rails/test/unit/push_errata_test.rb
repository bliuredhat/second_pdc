require 'test_helper'
require 'rake'

class PushErrataTest < ActiveSupport::TestCase

  setup do
    # Needs to be a valid advisory which is in REL_PREP
    @relprep = Errata.find(11138)

    # Without rhnqa set it will fail a state transition guard:
    # "Errata Advisory must be up to date on RHN Stage"
    @relprep.stubs(:rhnqa?).returns(true)

    # Needs security approval before it can go to PUSH_READY
    @relprep.update_attributes(:security_approved => true)

    # Without text_only_advisories_require_dists set it will fail a state
    # transition guard:
    # "Errata Advisory Must set at least one RHN Channel or CDN Repo"
    @relprep.product.update_attributes!(:text_only_advisories_require_dists => false)

    PushErrata.stubs(:relprep).returns([@relprep])
  end

  test "fixture data assumptions" do
    assert_equal State::REL_PREP, @relprep.status
  end

  {
    "no dates set"         => {                                       :should_change => true  },
    "future release date"  => { :release_ship_date => 1.day.from_now, :should_change => false },
    "future advisory date" => { :publish_date      => 1.day.from_now, :should_change => false },
    "past release date"    => { :release_ship_date => 1.day.ago,      :should_change => true  },
    "past advisory date"   => { :publish_date      => 1.day.ago,      :should_change => true  },
    "no dates and blocker" => { :blockers          => ["hey!"],       :should_change => false },

  }.each do |name, params|
    test "rel prep to push ready advisory with #{name}" do
      assert_behavior(params)
    end
  end

  def assert_behavior(params)
    @relprep.stubs(
      :release_ship_date => params[:release_ship_date],
      :publish_date_override => params[:publish_date],
      :push_ready_blockers => (params[:blockers] || []))

    PushErrata.move_rel_prep_to_push_ready

    expected_status = params[:should_change] ? State::PUSH_READY : State::REL_PREP
    assert_equal expected_status, @relprep.status
  end

  test 'rel prep to push ready delayed job behaves as expected' do
    now = Time.now

    assert_difference('Delayed::Job.count', 1) {
      Push::RelPrepToPushReadyJob.enqueue_once
    }

    payload = Delayed::Job.last.payload_object

    PushErrata.expects(:move_rel_prep_to_push_ready)
    payload.perform

    assert payload.rerun?
    assert payload.next_run_time >= now + Settings.rel_prep_to_push_ready_interval
  end

  test 'changing an advisory to REL_PREP enqueues to push ready delayed job' do
    e = Errata.find(16384)
    Push::RelPrepToPushReadyJob.expects(:enqueue_once)
    e.stubs(:stage_push_complete?).returns(true)
    e.change_state!('REL_PREP', User.default_qa_user)
  end

  test 'changing an advisory from NEW_FILES to QE does not enqueue pre-push job' do
    # Too early
    Push::PrepushTriggerJob.expects(:run_soon).never
    Errata.find(20292).change_state!('QE', devel_user)
  end

  test 'signing a build not enqueues pre-push job if errata is not in REL_PREP' do
    Push::PrepushTriggerJob.expects(:run_soon).never
    bb = BrewBuild.where(:signed_rpms_written => 0).first
    bb.signed_rpms_written = 1
    bb.save!
    assert_equal %w{NEW_FILES}, bb.errata.map(&:status)
  end

  test 'signing a build enqueues pre-push job' do
    bb = BrewBuild.find(155873)
    bb.update_attributes!({'signed_rpms_written' => false})
    assert bb.errata.map(&:status).include?("REL_PREP")

    Push::PrepushTriggerJob.expects(:run_soon)
    bb.update_attributes!({'signed_rpms_written' => true})
  end

  test 'visibility changes to a bug do not enqeue pre-push job if errata not in REL_PREP' do
    Push::PrepushTriggerJob.expects(:run_soon).never
    bug = Bug.find(693954)
    bug.is_private = false
    bug.save!
  end

  test 'making a security bug public enqueues pre-push job' do
    Push::PrepushTriggerJob.expects(:run_soon)
    bug = Bug.find(692421)
    bug.is_private = false
    bug.save!
  end

  test 'making a security bug not-security enqueues pre-push job' do
    Push::PrepushTriggerJob.expects(:run_soon)
    bug = Bug.find(692421)
    bug.is_security = false
    bug.save!
  end

  test 'changing package of security bug enqueues pre-push job' do
    Push::PrepushTriggerJob.expects(:run_soon)
    bug = Bug.find(692421)
    bug.package = Package.find_by_name!('kernel')
    bug.save!
  end

  test 'irrelevant bug updates do not enqueue pre-push job' do
    Push::PrepushTriggerJob.expects(:run_soon).never
    bug = Bug.find(692421)
    bug.summary = "updated #{bug.summary}"
    bug.save!
  end

  test 'run_soon reschedules pre-push job' do
    Delayed::Job.delete_all

    time1 = Time.now.change(:usec => 0, :nsec => 0)
    time2 = time1 + 3.hours

    Time.stubs(:now => time1)

    # since there's initially no job, this should create one
    assert_difference('Delayed::Job.count') do
      Push::PrepushTriggerJob.run_soon
    end

    created_job = Delayed::Job.last

    assert_equal time1, created_job.run_at

    # If run_soon was then called later, it won't create a new job, but it will update
    # the timestamp on the existing one
    Time.stubs(:now => time2)
    assert_no_difference('Delayed::Job.count') do
      Push::PrepushTriggerJob.run_soon
    end

    assert_equal time2, created_job.reload.run_at
  end

  test 'pre-push job basics' do
    job = Push::PrepushTriggerJob.new

    assert job.rerun?
    assert job.next_run_time > 1.hour.from_now

    PushErrata.expects(:trigger_prepush_for_eligible_errata).once
    job.perform
  end

  test 'prepush skipped according to setting' do
    Settings.use_prepush = false
    Errata.expects(:where).never
    PushErrata.trigger_prepush_for_eligible_errata
  end

  test 'pre-push jobs are triggered in eligable state' do
    Push::PrepushTriggerJob.expects(:run_soon)
    a = Errata.find(19030)
    a.change_state!('REL_PREP', User.default_qa_user)
  end

  test 'prepush triggers expected jobs' do
    eligible_status = %w(REL_PREP)

    # We need one advisory which is a) in REL_PREP, b) can not push to RHN. None
    # of the fixture datas advisories in REL_PREP currently provide that
    # combination. The tests makes several assertions against this exact
    # advisory.
    a = Errata.find(19030)
    a.change_state!('REL_PREP', User.default_qa_user)
    pv = a.product_versions[0]
    pv.push_targets.reject! { |pt| pt.name.include? "rhn" }

    max_id = PushJob.pluck('max(id)')

    # forcing delayed jobs to run now so push jobs are submitted
    force_sync_delayed_jobs do
      PushErrata.trigger_prepush_for_eligible_errata
    end

    jobs = PushJob.where('id > ?', max_id)

    # Ensure we created some jobs. This is a lower bound so the test doesn't need
    # updating when new fixtures are added.
    assert jobs.length >= 5

    # As we go, group the jobs by errata and type for further verification
    grouped_jobs = Hash.new do |h, k|
      h[k] = {}
    end

    jobs.each do |pj|
      errata = pj.errata
      msg = "failed for #{pj.class} #{pj.id} on errata #{errata.id}"

      # There should be only one job of each errata/type created
      assert_nil grouped_jobs[errata][pj.class], msg

      grouped_jobs[errata][pj.class] = pj

      # It should be a nochannel job
      assert pj.is_nochannel?, msg
      assert_equal User.system, pj.pushed_by
      assert pj.pub_options['push_files'], msg
      assert pj.pub_options['push_metadata'], msg
      assert_equal [], pj.pre_push_tasks, msg
      assert_equal [], pj.post_push_tasks, msg

      # It should have been submitted to pub
      assert_equal 'WAITING_ON_PUB', pj.status
      assert pj.pub_task_id

      # The log should explain it
      assert_match 'This is a pre-push job triggered automatically', pj.log

      # It should be for RHN or CDN live
      assert(pj.is_a?(CdnPushJob) || pj.is_a?(RhnLivePushJob), msg)

      # Advisory should have been in one of these states
      assert eligible_status.include?(errata.status), msg

      # All of the builds on this advisory must be signed
      errata.brew_builds.each do |bb|
        assert bb.signed_rpms_written?, "#{msg}, build #{bb.nvr}"
      end

      if (date = errata.embargo_date)
        # If there was an embargo date, it must be in the past
        assert date < Time.now.beginning_of_day
      end

      # There must be no embargoed bugs
      assert errata.embargoed_bugs.empty?

      # Prior to this newly created job, there should not have been any jobs of this
      # type since last respin.
      assert_equal [], errata.push_jobs_since_last_state(pj.class, 'NEW_FILES') - [pj], msg
    end

    # Fixtures should be broad enough to cover all of the eligible statuses
    assert_equal eligible_status, grouped_jobs.keys.map(&:status).uniq.sort

    # Now check some errata which should _NOT_ pre-push...

    Errata.find(10718).tap do |e|
      # This one should pre-push to RHN, but not CDN since it's not applicable
      assert e.has_rhn_live?
      refute e.has_cdn?

      assert grouped_jobs[e][RhnLivePushJob]
      refute grouped_jobs[e][CdnPushJob]
    end

    Errata.find(19030).tap do |e|
      # This one should pre-push to CDN, but not RHN since it's not applicable
      refute e.has_rhn_live?
      assert e.has_cdn?

      refute grouped_jobs[e][RhnLivePushJob]
      assert grouped_jobs[e][CdnPushJob]
    end

    Errata.find(11149).tap do |e|
      # This one has RHN live and all builds signed, but is NEW_FILES
      assert e.has_rhn_live?
      assert e.brew_builds.all?(&:signed_rpms_written?)
      assert_equal 'NEW_FILES', e.status

      refute grouped_jobs.has_key?(e)
    end

    Errata.find(11065).tap do |e|
      # This one has RHN live and QE, but some builds unsigned
      assert e.has_rhn_live?
      refute e.brew_builds.all?(&:signed_rpms_written?)
      assert_equal 'QE', e.status

      refute grouped_jobs.has_key?(e)
    end

    Errata.find(19028).tap do |e|
      # This one has RHN live and PUSH_READY, and all builds signed, but it already had an
      # RHN push job so pre-push was skipped
      assert e.has_rhn_live?
      assert e.brew_builds.all?(&:signed_rpms_written?)
      assert_equal 'PUSH_READY', e.status
      assert e.push_jobs_since_last_state(RhnLivePushJob, 'NEW_FILES').any?

      refute grouped_jobs.has_key?(e)
    end
  end

  test 'errata_for_prepush skips errata with embargoed bugs' do
    e = Errata.find(11110)
    e.change_state!('REL_PREP', User.default_qa_user)

    # This advisory initially has some embargoed bugs, thus is not eligible for pre-push
    assert e.embargoed_bugs.any?
    refute get_prepush_errata.include?(e)

    # Once the bugs are made public, the advisory is eligible for pre-push
    e.embargoed_bugs.each do |bug|
      bug.update_column(:is_private, false)
    end

    e.reload

    # Now it's OK for pre-push
    refute e.embargoed_bugs.any?
    assert get_prepush_errata.include?(e)
  end

  test 'ensure push_targets comes from both channels and repos' do
    e = Errata.find(16654)
    assert e.text_only_channel_list.get_all_channel_and_cdn_repos.empty?
    assert_array_equal ["rhn_stage", "rhn_live", "ftp", "cdn_stage", "cdn"],
                       e.push_targets.map(&:name)

    e.text_only_channel_list.set_cdn_repos_by_id([CdnRepo.first.id])
    assert_array_equal ["cdn_stage", "cdn"], e.push_targets.map(&:name)

    e.text_only_channel_list.set_channels_by_id([1351])
    assert_array_equal ["rhn_stage", "rhn_live", "cdn_stage", "cdn"],
                       e.push_targets.map(&:name)

    e.text_only_channel_list.cdn_repo_list = ''
    assert_array_equal ["rhn_stage", "rhn_live", "cdn"],
                       e.push_targets.map(&:name)
  end

  # Get the errata which would be pre-pushed if pre-push was now triggered.
  # Accurate, since it really triggers the pre-push (but rolls it back).
  def get_prepush_errata
    max_id = PushJob.pluck('max(id)')
    out = []
    ActiveRecord::Base.transaction do
      PushErrata.trigger_prepush_for_eligible_errata
      out.concat(PushJob.where('id > ?', max_id).map(&:errata))
      raise ActiveRecord::Rollback
    end
    out
  end
end
