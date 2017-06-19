module DistQaTpsTestHelper
  def with_unblocking_distqa_tps(erratum)
    # Make the advisory to use the state machine rule set
    rule = StateMachineRuleSet.find_by_name("Optional TPS DistQA")
    rule.releases << erratum.release
    rule.save!

    # Make sure we start the test in NEW_FILES state
    assert_equal State::NEW_FILES, erratum.status
    assert Tps.get_jobs_in_state(TpsState::NOT_STARTED, [erratum]).empty?

    pass_rpmdiff_runs(erratum)
    erratum.change_state!(State::QE, qa_user)

    # We quickly finish all non-rhnqa jobs in order to allow querying
    # for rhnqa_jobs
    erratum.tps_run.reload
    pass_tps_runs(erratum)
    sign_builds(erratum)

    job_types = []
    job_types << RhnStagePushJob if erratum.supports_rhn_stage?
    job_types << CdnStagePushJob if erratum.supports_cdn_stage?

    # Push to rhn and cdn stage
    # only 1 delayed jobs created here as there is no push delay:
    # 1) Pub watcher
    delayed_job_count =  1
    assert_difference("Delayed::Job.count", delayed_job_count) do
      jobs = do_push_jobs(erratum, job_types)
      # Add 1 minutes to this. If the test codes run between the change_state and push job
      # within 1 second, then no push jobs can be found.
      jobs.each do |job|
        job.updated_at += 1.minutes
        job.save!
      end
    end

    yield(erratum, Delayed::Job.last(delayed_job_count))

    # DistQA TPS test is optional so the advisory should allow to go to REL_PREP
    assert_nothing_raised do
      erratum.change_state!(State::REL_PREP, qa_user)
    end
    assert_equal State::REL_PREP, erratum.status
  end
end
