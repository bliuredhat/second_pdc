require 'test_helper'

class TpsRunTest < ActiveSupport::TestCase

  test "tps jobs scheduled for PDC advisory" do
    VCR.use_cassette('pdc_tps_jobs') do
      errata = Errata.find 10000
      assert errata.is_pdc?, 'Advisory should be pdc'
      assert errata.tps_run.nil?, 'TpsRun should be blank'
      assert_equal 'QE', errata.status
      errata.tps_run = TpsRun.create!(errata:errata)
      jobs = errata.tps_run.tps_jobs
      assert_equal 3, jobs.length, 'TPS Runs should be scheduled!'

      assert jobs.any? {|j| j.is_a? RhnTpsJob}, "RHN Jobs should be scheduled"
      assert jobs.any? {|j| j.is_a? CdnTpsJob}, "CDN Jobs should be scheduled"
    end
  end

  test "jobs finished" do
    stats = TpsRun.order(:run_id).reduce(ActiveSupport::OrderedHash.new) do |h,run|
      h.merge(run.run_id => {:jobs_finished => run.jobs_finished?})
    end
    assert_testdata_equal 'tps_completion_stats.yml', stats.to_yaml
  end

  test "tps jobs finished attribute" do
    assert rhba_async.tps_run.nil?

    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    assert rhba_async.tps_run.tps_jobs.any?

    # finish all jobs, reload tps_run and expect the query returns the
    # correct result with all jobs finished
    finish_tps_jobs(rhba_async, :tps)

    rhba_async.tps_run.reload
    assert rhba_async.tps_run.jobs_finished?
    assert rhba_async.tps_run.tps_jobs.map(
      &:state_id).select {|id| id != TpsState::GOOD }.empty?
  end

  test "tps rhnqa jobs finished" do
    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    #
    # The RHNQA jobs have not been initialized, therefore can not be
    # finished.
    #
    refute rhba_async.tps_run.rhnqa_jobs_finished?
    refute rhba_async.tps_run.jobs_finished?, "Jobs should not be finished! #{rhba_async.tps_run.tps_jobs.length}"

    #
    # Finish all tps jobs.
    #
    # Note: It will not finish the rhnqa_jobs, since they're not
    # initialized yet.
    #
    pass_tps_runs
    assert rhba_async.tps_run.jobs_finished?
    refute rhba_async.tps_run.rhnqa_jobs_finished?

    # usually done by RhnStagePushJob
    Tps::Scheduler.schedule_rhnqa_jobs(rhba_async.tps_run)
    refute rhba_async.tps_run.rhnqa_jobs_finished?

    pass_tps_runs
    assert rhba_async.tps_run.rhnqa_jobs_finished?
  end

  test "rhnqa jobs are initialized?" do
    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    refute rhba_async.tps_run.rhnqa_jobs_initialized?

    #
    # This should never happen if we consider Bug #1050759 fixed, but
    # we'll test it anyway. The tps jobs should be finished before rhnqa
    # jobs are initialized by the RhnStagePushJob
    #
    Tps::Scheduler.schedule_rhnqa_jobs(rhba_async.tps_run)
    refute rhba_async.tps_run.rhnqa_jobs_initialized?

    pass_tps_runs
    rhba_async.tps_run.rhnqa_jobs_initialized?
  end

  def finish_tps_jobs(advisory, jobtype)
    jobs_attr = (jobtype == :tps) ? :tps_jobs : :rhnqa_jobs
    advisory.tps_run.send(jobs_attr).map do |job|
      advisory.tps_run.update_job(
        job, TpsState.where(:id => TpsState::GOOD).first, '', '')
    end
  end

  #
  # The rhnqa jobs are initialized after packges have been pushed to
  # staging. The job queue includes them however, after the advisorys
  # rhnqa attribute is set to true.
  #
  test "RHNQA jobs not initialized after QE state change" do
    assert rhba_async.tps_run.nil?

    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)
    assert rhba_async.tps_run.tps_jobs.any?
    assert rhba_async.tps_run.rhnqa_jobs.empty?
  end

  test "RHNQA jobs are initialized after stage push" do
    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    pass_tps_runs
    sign_builds
    assert rhba_async.tps_run.rhnqa_jobs.empty?, "RHNQA Jobs not empty!"
    assert Tps.get_jobs_in_state(TpsState::NOT_STARTED, [rhba_async]).empty?
    assert rhba_async.rhnqa == 0

    #
    # One of the post_push_tasks sets the rhnqa attribute of the
    # advisory to true. We expect one delayed job to be created
    #
    # In order to schedule the RHNQA jobs in the job queue, the advisory
    # has to be set to rhnqa = true.
    #
    job = RhnStagePushJob.create!(:errata => rhba_async, :pushed_by => qa_user)
    handler_query = "handler like '%#{rhba_async.id}\nmethod: :update_attribute%' AND handler like '%- :rhnqa\n- true%'"
    job.pub_success!
    # There is no delay on stage push
    refute Delayed::Job.where(handler_query).exists?

    #
    # Up until the stage push, no rhnqa jobs have been created. The job
    # has passed and the rhnqa jobs are initialized. That doesn't mean
    # they're included in the tps job queue tho.
    #
    assert rhba_async.tps_run.rhnqa_jobs.any?

    rhba_async.reload
    assert rhba_async.rhnqa == 1
    assert Tps.get_jobs_in_state(TpsState::NOT_STARTED, [rhba_async]).any?
  end

  # Bug 1147211
  test "stage push jobs don't try to reschedule TPS if TPS is not used" do
    rule_set = rhba_async.state_machine_rule_set
    rule_set.test_requirements = rule_set.test_requirements.delete('tps')
    rule_set.save!

    # advisory should now be considered to not use TPS
    refute rhba_async.requires_tps?

    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    sign_builds

    [CdnStagePushJob,RhnStagePushJob].each do |klass|
      job = klass.create!(:errata => rhba_async, :pushed_by => qa_user)
      assert_nothing_raised("failed on #{klass}") do
        job.pub_success!
      end
      assert_equal 'COMPLETE', job.reload.status, "job status differs from expected for #{klass}"
    end
  end

  test "enforces tps method works as expected when changing tps guard type" do
    {
      'block' => true,
      'info' => false,
      'waive' => true,
    }.each_pair do |tps_guard_type, expected|
      rhba_async.state_machine_rule_set.state_transition_guards.where(:type => 'TpsGuard').update_all(:guard_type => tps_guard_type)
      assert_equal expected, rhba_async.enforces_tps?
    end
  end

  #
  # Bug: 961376
  #
  test "sends correct email headers for rescheduling jobs" do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    job = RhnTpsJob.find(199454)
    job.tps_state = TpsState.find(TpsState::BUSY)
    TpsRun.any_instance.stubs(:is_finished?).once.returns(true)
    TpsRun.find(21447).update_job(job, TpsState.where(:id => TpsState::GOOD).first, '', '')

    mail = ActionMailer::Base.deliveries.pop
    assert_equal 'TPS', mail.header['X-ErrataTool-Component'].value
    assert_equal 'TPS_RUNS_COMPLETE', mail.header['X-ErrataTool-Action'].value
  end

  test "successfully reschedules failed distqa jobs" do
    run = TpsRun.find(10253)
    job = CdnQaTpsJob.create!(
      :run => run,
      :arch => Arch.first,
      :cdn_repo => CdnBinaryRepo.first,
      :variant => Variant.first,
      :started => Time.now
    )
    job.update_attribute(:state_id, TpsState::BAD)

    assert_equal [TpsState::BAD], run.distqa_jobs.map(&:state_id).uniq

    run.reschedule_failure_distqa_jobs!
    run.reload
    comment = run.errata.comments.last
    assert_equal [TpsState::NOT_STARTED], run.distqa_jobs.map(&:state_id).uniq
    assert_equal %w{CdnQaTpsJob RhnQaTpsJob}.sort, run.distqa_jobs.map(&:class).map(&:name).uniq.sort
    assert_match 'Rescheduled all BAD Distqa Jobs', comment.text
  end

  test "successfully reschedules distqa jobs" do
    pass_rpmdiff_runs rhba_async
    rhba_async.change_state!(State::QE, qa_user)

    rhba_async.tps_run.reschedule_distqa_jobs!
    assert rhba_async.tps_run.distqa_jobs.any?
  end

  test "run finished without duplicated comments" do
    run = TpsRun.find(21447)
    job1 = RhnTpsJob.find(199454);
    job2 = RhnTpsJob.find(199453);

    job1.update_attribute(:state_id, TpsState::NOT_STARTED)
    job2.update_attribute(:state_id, TpsState::NOT_STARTED)

    assert_difference 'run.errata.comments.count', 0 do
      TpsService.new.jobReport(job1.id, run.id, 'GOOD', '', '', '')
    end

    assert_difference 'run.errata.comments.count', 1 do
      3.times do
        TpsService.new.jobReport(job2.id, run.id, 'GOOD', '', '', '')
      end
    end
  end
end
