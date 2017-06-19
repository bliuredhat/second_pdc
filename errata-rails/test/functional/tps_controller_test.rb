require 'test_helper'
require 'fileutils'

class TpsControllerTest < ActionController::TestCase

  def setup
    # For reschedule tests
    # To choose a suitable tps job:
    #  RhnTpsJob.host_set.where("state_id != ?", TpsState::NOT_STARTED).last
    @tps_job = RhnTpsJob.find(111982)
    @tps_run = @tps_job.run
    @errata = @tps_job.errata
    @comment_count = @errata.comments.count
    @new_build = BrewBuild.find_by_nvr('python-crypto-2.6.1-1.2.el7cp')
    @new_bugs = Bug.find(581482)

    # For waive tests
    @tps_job_to_waive = RhnTpsJob.host_set.with_states(TpsState::BAD).channel_set.last
    @rhnqa_job_to_waive = RhnQaTpsJob.host_set.with_states(TpsState::BAD).channel_set.last

    # For unwaive tests
    @tps_job_to_unwaive = RhnTpsJob.host_set.with_states(TpsState::WAIVED).channel_set.last
    @rhnqa_job_to_unwaive = RhnQaTpsJob.host_set.with_states(TpsState::WAIVED).channel_set.last

    #
    # Create the tps.txt file, which is being used in
    # test_list_open_jobs. Remove it in the test tear down.
    #
    FileUtils.touch Rails.root.join("public/tps.txt")

    auth_as devel_user
  end

  test "reschedule Tps jobs after remove and add new build" do

    VCR.use_cassette 'create a pdc advisory and build the Tps jobs' do
      @pdc_errata = Errata.find(10000)
      @pdc_errata.tps_run = TpsRun.create!(errata:@pdc_errata)
      jobs = @pdc_errata.tps_run.tps_jobs
      assert @pdc_errata.is_pdc?
      assert_equal 'QE', @pdc_errata.status
      finish_tps_jobs(@pdc_errata, :tps)
      assert @pdc_errata.tps_run.jobs_finished?
      assert_equal 3, jobs.length, 'TPS Runs should be scheduled!'

      # Change to 'NEW_FILE' state
      @pdc_errata.change_state!(State::NEW_FILES, qa_user)

      # Remove the exsited builds
      @pdc_errata.build_mappings.where(:brew_build_id => BrewBuild.find_by_nvr!('ceph-10.2.3-17.el7cp').id).each(&:obsolete!)

      # Add a new build
      @pdc_errata.pdc_errata_releases.first.brew_builds << @new_build

      # Add a Bug for this advisory
      FiledBug.create!(:bug => @new_bugs, :errata => @pdc_errata)

      # Do the RpmdiffRun task
      RpmdiffRun.schedule_runs(@pdc_errata)
      pass_rpmdiff_runs @pdc_errata

      # Reschedule the tps jobs
      ignore_non_tps_guards
      @pdc_errata.change_state!(State::QE, qa_user)
      jobs = @pdc_errata.tps_run.tps_jobs
      assert_equal 1, jobs.length
      tps_state = @pdc_errata.tps_run.tps_jobs.first.tps_state.state
      assert_equal "NOT_STARTED", tps_state
    end
  end

  def ignore_non_tps_guards
    StateTransitionGuard.descendants.each do |guard|
      next if guard.to_s =~ /tps/i
      guard.any_instance.stubs(:transition_ok? => true)
    end
  end

  def finish_tps_jobs(advisory, jobtype)
    jobs_attr = (jobtype == :tps) ? :tps_jobs : :rhnqa_jobs
    advisory.tps_run.send(jobs_attr).map do |job|
      advisory.tps_run.update_job(
      job, TpsState.where(:id => TpsState::GOOD).first, '', '')
    end
  end

  def teardown
    #
    # Use force. In case the file doesn't exist, don't complain since the
    # setup might have been unsuccessful.
    #
    FileUtils.rm(Rails.root.join("public/tps.txt"), :force => true)
  end

  def assert_redirected_as_expected(job)
    assert_redirected_to :action=>(job.rhnqa? ? :rhnqa_results : :errata_results), :id=>job.run.id
  end

  def assert_filters_equal(expected, params)
    @controller.params = params
    advisories = @controller.send(:query_advisories_for_job_map)
    assert_equal expected, advisories.count
  end

  #
  # If we keep the asserts in the setup method, it will mess with the database
  # and not rollback to it's initial state :(
  #
  test "testsetup has valid jobs" do
    assert @tps_job.host.present?
    assert !@tps_job.is_state?('NOT_STARTED')
  end

  test "delete job" do
    auth_as qa_user
    post :delete_tps_job, :id => @tps_job
    assert_response :success
    assert_equal "$('#tps_job_#{@tps_job.id}').remove();", response.body
    refute TpsJob.exists? @tps_job.id
  end

  test "reschedule rhn job redirects to tps run view" do
    post :schedule_job, :id=>@tps_job, :format => :js
    assert_response :ok, response.body

    @tps_job.reload # otherwise won't notice updated host..

    # Supposed to clear the host, see Bug 914722
    assert @tps_job.host.blank?, "Host should be cleared for resheduled TPS run"

    # Should have change state to not started
    assert @tps_job.is_state?('NOT_STARTED'), "Rescheduled TPS job should be NOT_STARTED"
  end

  test "rescheduling rhn job should have add a comment" do
    assert_difference('Comment.count') do
      post :schedule_job, :id=>@tps_job, :format => :js
    end
    comment = @errata.comments.last
    assert comment.is_a?(TpsComment)
    assert_match %r{^Rescheduling}, comment.text
  end

  test "reschedule rhnqa job redirects to rhnqa view" do
    rhnqa_job = RhnQaTpsJob.last
    post :schedule_job, :id => rhnqa_job, :format => :js
    assert_response :ok, response.body
  end

  test "reschedule cdnqa job redirects to rhnqa view" do
    cdnqa_job = CdnQaTpsJob.create!(
      :run => @tps_run,
      :cdn_repo => CdnBinaryRepo.last,
      :arch => Arch.last,
      :variant => Variant.rhel_variants.last,
      :started => Time.now
    )
    post :schedule_job, :id => cdnqa_job.id, :format => :js
    assert_response :ok, response.body
  end

  test "reschedule all jobs" do
    post :reschedule_all, :id=>@tps_run
    assert_redirected_to :action=>:errata_results, :id=>@tps_run
    assert_equal "All TPS Jobs have been rescheduled.", flash[:notice]

    @tps_run.tps_jobs.each do |tps_job|
      assert tps_job.is_state?('NOT_STARTED')
      assert tps_job.host.blank?
    end

    assert_equal @comment_count + 1, @errata.comments.count
    comment = @errata.comments.last
    assert comment.is_a?(TpsComment)
    assert_match /^Rescheduled all/, comment.text
  end

  test "successfully reschedules all distqa jobs" do
    post :reschedule_all_distqa, :id => @tps_run

    assert_redirected_to :action => :rhnqa_results, :id => @tps_run
    assert_match %r{DistQA.*rescheduled}, flash[:notice]
  end

  test "successfully reschedules all bad tps jobs" do
    jobs = [@tps_job_to_waive, @rhnqa_job_to_waive]
    controller_methods = [:reschedule_all_failure, :reschedule_all_rhnqa_failure]

    jobs.zip(controller_methods).each do |job, method|
      tps_run = job.run

      post method, :id => tps_run
      assert_response :redirect

      job.reload
      assert job.is_state?('NOT_STARTED')
    end
  end

  test "check for missing tps jobs" do
    assert_schedules_missing_job(@tps_run, :tps_jobs)
  end

  test "create rhnqa jobs but don't schedule them in manual mode" do
    # Make the advisory to use the state machine rule set
    rule = StateMachineRuleSet.find_by_name("Optional TPS DistQA")
    rule.releases << @tps_run.errata.release
    rule.save!
    assert_schedules_missing_job(@tps_run, :rhnqa_jobs, false)
  end

  test "check for missing rhnqa jobs" do
    # (Some assertions in this test assume that TPS CDN is disabled)
    Settings.stubs(:enable_tps_cdn).returns(false)

    #
    # Not sure if finished tps_runs are making such a good test case. Perhaps
    # it'll be more realistic if they wouldn't be finished?
    #
    # Errata.where('rhnqa = 1').rel_prep.last
    #
    advisory = Errata.find(11118)

    assert_schedules_missing_job(advisory.tps_run, :rhnqa_jobs)
  end

  def assert_schedules_missing_job(run, job_type, should_schedule = true)
    controller_method = :check_for_missing_jobs
    controller_method = :check_for_missing_rhnqa_jobs if job_type == :rhnqa_jobs

    first_job = run.send(job_type).first
    amount = run.send(job_type).count

    # delete 1 job
    assert_difference("TpsJob.count", -1) do
      post :delete_tps_job, :id => first_job
    end
    run.reload
    assert_response :success
    assert_equal amount - 1, run.send(job_type).count

    # make sure the deleted job is created again
    assert_difference("TpsJob.count", +1) do
      post controller_method, :id => run
    end
    run.reload
    assert_response :redirect
    assert_match %r{^Created 1 new jobs}, flash[:notice]
    assert_equal amount, run.send(job_type).count

    expected_state = should_schedule ? TpsState::NOT_STARTED : TpsState::NOT_SCHEDULED
    assert_equal(
      expected_state,
      run.send(job_type).last.state_id,
      "TPS state is expected to be '#{TpsState.find(expected_state).state}'."
    )
  end

  # Qa user should be able to waive (Bz 991541)
  test "waive/unwaive jobs as qa user" do
    auth_as qa_user

    [@tps_job_to_waive, @rhnqa_job_to_waive].each do |job|
      assert job.is_state?('BAD')

      post :waive, :id=>job
      assert_redirected_as_expected(job)
      assert_nil flash[:error]
      assert job.reload.is_state?('WAIVED')

      post :unwaive, :id=>job
      assert_redirected_as_expected(job)
      assert_nil flash[:error]
      assert job.reload.is_state?('BAD')
    end
  end

  # Non qa user should not be able to waive (Bz 991541)
  test "waive a job as devel user" do
    [@tps_job_to_waive, @rhnqa_job_to_waive].each do |job|
      assert job.is_state?('BAD')
      post :waive, :id=>job
      assert_redirected_as_expected(job)
      assert_equal "User not permitted to waive TPS jobs.", flash[:error]
      flash.clear
      assert job.reload.is_state?('BAD')
    end
  end

  # But unwaive should work fine
  test "unwaive job as devel user" do
    [@tps_job_to_unwaive, @rhnqa_job_to_unwaive].each do |job|
      assert job.is_state?('WAIVED')
      post :unwaive, :id=>job
      assert_redirected_as_expected(job)
      assert_nil flash[:error]
      assert job.reload.is_state?('BAD')
    end
  end

  test "query advisories for job map" do
    # No filter
    assert_filters_equal Errata.qe.count, {}

    # Filter by release
    release = Errata.qe.last.release
    assert_filters_equal Errata.qe.where(:group_id => release).count, :release_id => release.id.to_s
    assert assigns :release_filter

    # Filter by product
    product = Errata.qe.last.product
    assert_filters_equal Errata.qe.where(:product_id => product).count, :product_id => product.id.to_s
    assert assigns :product_filter

    # Filter by team
    team = Errata.qe.last.quality_responsibility
    assert_filters_equal Errata.qe.where(:quality_responsibility_id => team).count, :quality_responsibility_id => team.id.to_s
    assert assigns :qe_team_filter
  end

  test "list open jobs" do
    auth_as qa_user
    now = Time.at(0)
    File.stubs(:mtime).at_least_once.returns(now)

    # This test assumes that fixtures contain no open jobs, which was
    # true at some point, but open jobs were later added.  Use a scope
    # to constrain the test to consider only a set of jobs known to be
    # closed
    TpsJob.with_scope(:find => {:conditions => 'job_id < 198286'}) do
      get :open_jobs
      assert assigns(:jobs).empty?
      assert_equal now.to_s(:long), assigns(:last_published)

      File.stubs(:exists?).returns(false)
      get :open_jobs
      assert assigns(:jobs).empty?
      assert_match /tps.*missing/, assigns(:last_published)
    end
  end

  test "delete jobs" do
    advisory = Errata.find(11152)

    assert_difference("TpsJob.count", -1) do
      post :delete_tps_job, :id => advisory.tps_run.tps_jobs.last.id
    end
    assert_response :success
  end

  test "jobs_for_errata returns the correct amount of rhn tps jobs" do
    auth_as qa_user

    Settings.stubs(:enable_tps_cdn).returns(true)
    expected_fields = [ :job_id, :run_id, :arch, :version, :host, :state,
      :started, :finished, :link, :link_text, :rhnqa, :repo_name, :tps_stream,
      :config ].map(&:to_s).sort

    post :jobs_for_errata, :format => :json, :id=> @errata.id
    result = ActiveSupport::JSON.decode response.body

    expected_jobs = @errata.tps_run.tps_jobs.count + @errata.tps_run.rhnqa_jobs.count
    assert_response :success
    assert result.any?
    assert_equal expected_jobs, result.count

    first_result = result.first
    assert_equal expected_fields, first_result.keys.sort
  end

  test "loads rhnqa_results view successfully" do
    auth_as qa_user

    # Bug 1254489, test this page twice to make sure the 'DistQA TPS test is not blocking...'
    # message will never be shown even if the advisory state has changed.
    2.times do
      get :rhnqa_results, :id => @errata.tps_run
      assert_response :success
      assert_no_match /DistQA TPS test is not blocking for this release/, response.body
      assert_no_match /for more information/, response.body
      assert_no_match /The DistQA TPS jobs you see here were not scheduled/, response.body
      @errata.change_state!('NEW_FILES', qa_user) if @errata.status != 'NEW_FILES'
    end
  end

  test "rhnqa_results view should show info message if rhnqa is not block" do
    auth_as qa_user

    info_links = {'RHEL-5.7.0' => 'http://more_info_link.com'}
    Settings.stubs(:tps_no_blocking_info_links).returns(info_links)
    # Make the advisory to use the state machine rule set
    rule = StateMachineRuleSet.find_by_name("Optional TPS DistQA")
    rule.releases << @errata.release
    rule.save!

    get :rhnqa_results, :id => @errata.tps_run
    assert_response :success
    assert_match /DistQA TPS test is not blocking for this release/, response.body
    assert_match /#{info_links['RHEL-5.7.0']}/, response.body
    assert_match /The DistQA TPS jobs you see here were not scheduled/, response.body
  end

  test "controller looks up tps run from advisory id" do
    params = {:id => @errata.fulladvisory }
    @controller.stubs(:params).returns(params)
    @controller.send(:find_tps_run)
    assert assigns(:errata) == @errata
  end

  test "tps run shows failing tps jobs" do
    get :failing_jobs, :id => @errata.id
    assert_response :success
    assert assigns(:jobs)
    assert TpsJob.with_states(TpsState::BAD).includes(assigns(:jobs))
  end

  test "job queue redirects to running jobs" do
    get :job_queue, :id => @errata.id
    assert_redirected_to :action => :running_jobs
  end

  test 'testdata preconditions' do
    run = TpsRun.find(21443)
    # there should be one CDN job with a deleted repo
    assert_equal [198289], run.cdn_tps_jobs.reject(&:cdn_repo).map(&:id)
  end

  test 'lists tps jobs OK if repos were deleted' do
    get :errata_results, :id => 21443
    assert_response :success

    # the problematic job should still show up in the UI
    assert_match %r{\b198289\b}, response.body
  end

  test 'reschedule_all is OK if repos were deleted' do
    logs = capture_logs {
      post :reschedule_all, :id => 21443
    }

    assert_redirected_to :action => :errata_results, :id => 21443
    assert_equal 'All TPS Jobs have been rescheduled.', flash[:notice]

    infologs = logs.select{|l| l[:severity] == 'INFO'}.map{|l| l[:msg]}

    # it should have gracefully removed the job for the deleted repo
    assert infologs.include?('Removed CdnTpsJob 198289 for deleted repo 9991269; no longer relevant'), infologs.join("\n")
  end

  test 'reschedule_job is OK if repos were deleted' do
    job = CdnTpsJob.find(198289)
    assert_nil job.cdn_repo

    assert_difference('TpsJob.count', -1) do
      post :schedule_job, :id => job.id, :format => :js
      assert_response :ok, response.body
    end

    assert_equal 'Job 198289 removed (Cdn repo no longer exists)', assigns(:notice)
  end

  test 'waive is OK if repos were deleted' do
    auth_as qa_user

    job = CdnTpsJob.find(198289)
    assert_nil job.cdn_repo

    assert_not_equal TpsState::WAIVED, job.reload.tps_state.id

    post :waive, :id => job.id
    assert_response :redirect, response.body

    assert_equal TpsState::WAIVED, job.reload.tps_state.id
  end

  def create_test_errata
    rhba = create_test_rhba("RHEL-6.3.0", "autotrace-0.31.1-26.el6")
    pass_rpmdiff_runs(rhba)
    rhba.change_state!(State::QE, qa_user)
    rhba
  end

  test "help panel should display correct messages" do
    Settings.stubs(:enable_tps_cdn).returns(true)
    rhba = create_test_errata

    # help panel should tell user that all repos are able to run tps
    get :troubleshooter, :id => rhba.tps_run.id, :format => :js

    [ "All RHN Channels have TPS scheduling enabled",
      "All CDN Repositories have TPS scheduling enabled"].each do |message|
      assert_match(/#{Regexp.escape(message)}/, response.body)
    end

    # help panel should tell user that 1 rhn channel and 1 cdn repo are not able to run tps
    channel = rhba.tps_run.rhn_tps_jobs.first.channel
    cdn_repo = rhba.tps_run.cdn_tps_jobs.first.cdn_repo
    [channel, cdn_repo].each do |repo|
      repo.update_attributes(:has_stable_systems_subscribed => false)
    end

    get :troubleshooter, :id => rhba.tps_run.id, :format => :js

    [channel.name, cdn_repo.name].each do |repo_name|
      assert_match(/#{Regexp.escape(repo_name)}/, response.body)
    end

    # help panel should tell user that rhn or cdn push not supported
    RHBA.any_instance.expects(:supports_cdn_stage?).at_least_once.returns(false)
    RHBA.any_instance.expects(:supports_cdn_live?).at_least_once.returns(false)
    RHBA.any_instance.expects(:supports_rhn_stage?).at_least_once.returns(false)
    RHBA.any_instance.expects(:supports_rhn_live?).at_least_once.returns(false)

    get :troubleshooter, :id => rhba.tps_run.id, :format => :js

    [ "This advisory doesn&#x27;t support RHN push",
      "This advisory doesn&#x27;t support CDN push"].each do |message|
      assert_match(/#{Regexp.escape(message)}/, response.body)
    end

    # help panel should tell user that cdn is disabled in Errata Tool
    Settings.stubs(:enable_tps_cdn).returns(false)

    get :troubleshooter, :id => rhba.tps_run.id, :format => :js

    assert_match(/#{Regexp.escape("CDN push is disabled in Errata Tool")}/, response.body)
  end

  test "help panel should tell user that no cdn repos or rhn channels is applicable" do
    Settings.stubs(:enable_tps_cdn).returns(true)
    rhba = create_test_errata
    Push::Cdn.stubs(:cdn_repos_for_errata).returns([])
    Push::Rhn.stubs(:channels_for_errata).returns([])

    get :troubleshooter, :id => rhba.tps_run.id, :format => :js

    [ "No RHN Channel is applicable to this advisory",
      "No CDN Repository is applicable to this advisory"].each do |message|
      assert_match(/#{Regexp.escape(message)}/, response.body)
    end
  end

  test "delete invalid jobs" do
    assert_no_difference("TpsJob.count") do
      post :delete_invalid_tps_jobs, :id => 21443
    end
    assert_equal "No invalid TPS jobs found.", flash[:alert]

    # Disable both Z and Main TPS Stream to make some jobs invalid
    ["RHEL-7.0-Z-Server", "RHEL-7-Main-Server"].each do |name|
      TpsStream.get_by_full_name(name).first.update_attributes!(:active => false)
    end

    # Reschedule all jobs so that all jobs are in incompleted state.
    # Completed jobs will always consider valid.
    assert_difference("TpsJob.count", -3) do
      post :reschedule_all, :id => 21443
      post :delete_invalid_tps_jobs, :id => 21443
    end
    assert_match(/Deleted invalid TPS jobs/, flash[:notice])
  end
end
