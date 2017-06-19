require 'test_helper'

class TpsJobQueueTest < ActiveSupport::TestCase

  test "job queue excludes job if repo name is nil" do
    t1 = mock('TpsJob').tap { |m|
      m.expects(:repo_name).once.returns(nil) }

    t2 = mock('TpsJob').tap { |m|
      m.expects(:repo_name).twice.returns('test_channel')
      m.stubs(:id).returns(2)
      m.expects(:errata).once.returns(Errata.last) }

    t3 = mock('TpsJob').tap { |m|
      m.expects(:repo_name).twice.returns('rhel-7-server-rpms')
      m.stubs(:id).returns(3)
      m.expects(:errata).once.returns(Errata.last) }

    t4 = mock('TpsJob').tap { |m|
      m.expects(:repo_name).once.returns(nil) }

    Tps.stubs(:get_jobs_in_state).with(equals(TpsState::NOT_STARTED), instance_of(Errata.qe.class)).once.returns([t1, t2, t3, t4])

    jobs = Tps.job_queue
    assert_equal 2, jobs.count
    assert_equal [2, 3], jobs.map{ |j| j[:job].id }
  end

  test "job queue published to text" do
    Tps.expects(:write_to).once.with(instance_of(Array), instance_of(File))
    Tps.stubs(:job_queue).returns([])

    Tps.publish_job_queue
  end

  test "job queue writes job specs to file" do
    stream = StringIO.new
    job = TpsJob.not_started.last
    job_entry = {:job => job, :errata => job.errata, :channel => job.channel}
    expected = 'job,txt,line.csv'
    TpsJob.expects(:tps_txt_queue_entry).twice.returns(expected)

    Tps.write_to([job_entry, job_entry], stream)
    assert stream.closed?
    assert_equal [expected, expected, ''].join("\n"), stream.string
  end

  test "job queue does not return jobs without a channel" do
    # (Some assertions in this test assume that TPS CDN is disabled)
    Settings.stubs(:enable_tps_cdn).returns(false)

    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)
    rhba_async.update_attribute('rhnqa', 1)

    #
    # Jobs without a channel will not be returned
    # Note: Just for this test we're setting an arbitrary channel.
    #
    jobs = Tps.get_jobs_in_state(TpsState::NOT_STARTED, [rhba_async])
    refute jobs.any? {|j| j.channel.nil?}, "Jobs with nil channels exist"
  end

  test "rhnqa jobs created and run" do
    # (Some assertions in this test assume that TPS CDN is disabled)
    Settings.stubs(:enable_tps_cdn).returns(false)

    assert Tps.get_jobs_in_state(TpsState::NOT_STARTED, [rhba_async]).empty?

    pass_rpmdiff_runs
    rhba_async.change_state!(State::QE, qa_user)

    #
    # Note: No RHNQA jobs should be included if the tps jobs haven't been run
    #
    # We quickly finish all non-rhnqa jobs in order to allow querying
    # for rhnqa_jobs
    #
    rhba_async.tps_run.reload
    pass_tps_runs
    assert rhba_async.tps_run.jobs_finished?

    #
    # Unless the advisory is marked as rhnqa == 1 no rhnqa jobs are
    # returned.
    # In order to delay RHNQA test runs, advisories are set to rhnqa
    # with a 30min delay (Bug #1050759).
    # The rhnqa attribute is set to true with a 30 delay in
    #
    #   app/models/rhn_stage_push_job.rb
    #
    # For more testing of the 30min delay and Bug #1050759, see:
    #
    #   test/unit/tps_run_test.rb
    #
    refute Tps.get_jobs_in_state(TpsState::NOT_STARTED, [rhba_async]).any?
    tps_run = rhba_async.tps_run
    tps_run.create_and_schedule_rhnqa_jobs!
    jobs = tps_run.reload.rhnqa_jobs

    assert jobs.length > 0, "No jobs created?"
    rhba_async.update_attribute('rhnqa', 1)

    #
    # Set the start date to "now" and all of them will be included in the
    # queue
    #
    assert Tps.get_jobs_in_state(TpsState::NOT_STARTED, [rhba_async]).any?,
           "No jobs available!"
  end

  test "rhnqa should not schedule by ET in manual mode" do
    with_unblocking_distqa_tps(rhba_async) do |erratum, delayed_jobs|
      # rhnqa flag is false due to the 30 mins delay
      # DistQA TPS jobs should not visible in tps job queue due to the 30 mins delay
      refute erratum.rhnqa?
      assert erratum.tps_run.distqa_jobs.count > 1, "Should have more than 1 DistQA TPS jobs."
      refute Tps.get_jobs_in_state(TpsState::NOT_STARTED, [erratum]).any?

      # Invoke delayed jobs to set the rhnqa flag to true
      delayed_jobs.map(&:invoke_job)

      # DistQA TPS jobs still should not visible in tps job queue because the scheduling mode
      # has been set to manual
      erratum.reload
      assert erratum.rhnqa?
      refute erratum.tps_run.distqa_jobs.any?{|j| j.state_id != TpsState::NOT_SCHEDULED }
      refute Tps.get_jobs_in_state(TpsState::NOT_STARTED, [erratum]).any?

      # Schedule a job
      erratum.tps_run.distqa_jobs.first.reschedule!
      # The scheduled job should now appear in the tps job queue
      assert_equal(
        1,
        Tps.get_jobs_in_state(TpsState::NOT_STARTED, [erratum]).count,
        "Should have 1 scheduled job."
      )
    end
  end
end
