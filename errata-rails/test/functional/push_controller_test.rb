require 'test_helper'
require 'nokogiri'

class PushControllerTest < ActionController::TestCase

  setup do
    @push_options = {
      "options" => {"push_files"=>"1", "push_metadata"=>"1"},
      "post_tasks" => {
        "push_oval_to_secalert"    => "0",
        "move_pushed_errata"       => "1",
        "request_translation"      => "0",
        "update_bugzilla"          => "1",
        "push_xml_to_secalert"     => "0"
      },
      "pre_tasks" => {"set_update_date"=>"1", "set_issue_date"=>"0"}
    }

    @rhn_stage_push_options = @push_options.dup
    # stage uses different tasks
    @rhn_stage_push_options['pre_tasks'] = {}
    @rhn_stage_push_options['post_tasks'] = {
      "mark_rhnqa_done" => "1",
      "reschedule_rhnqa" => "1",
    }

    @cdn_push_options = @push_options.dup
    # CDN uses mostly the same tasks except a few RHN-specific
    @cdn_push_options['post_tasks'] = @cdn_push_options['post_tasks'].reject{|k,v| %w{move_pushed_errata}.include?(k)}

    @rhn_advisory = Errata.find(11110)
    @cdn_advisory = Errata.find(16374)
    @rhn_cdn_advisory = Errata.find(10836)

    @rhn_nopush_advisory = Errata.find(11152)
    @cdn_nopush_advisory = Errata.find(16384)
    @rhn_cdn_nopush_advisory = Errata.find(11145)
  end

  test "advisory can push to RHN stage" do
    auth_as releng_user
    assert_difference('RhnStagePushJob.count') do
      post :push_errata_submit,
        :id => Errata.push_ready.first,
        :stage => 1,
        :cdn_stage => 0,
        :rhn_stage => 1,
        :push_options_fields => {
        :rhn_push_job => @rhn_stage_push_options
      }
    end
    assert_response :success
    push_job = RhnStagePushJob.last
    assert_equal Errata.push_ready.first, push_job.errata
    assert_same_push_tasks :post, @push_options, push_job
    assert_same_push_tasks :pre, @push_options, push_job
  end

  test "advisory can push to RHN" do
    auth_as releng_user
    e = Errata.push_ready.first
    assert_difference('RhnLivePushJob.count') do
      post :push_errata_submit,
        :id => e.id,
        :cdn_live => 0,
        :rhn_live => 1,
        :push_options_fields => {
        :rhn_push_job => @push_options
      }
    end
    assert_response :success
    push_job = RhnLivePushJob.last
    assert_equal e.reload, push_job.errata
    assert_same_push_tasks :post, @push_options, push_job
    assert_same_push_tasks :pre, @push_options, push_job
  end

  test "push page shows file details" do
    auth_as releng_user

    get :push_errata, :id => @rhn_cdn_advisory
    assert_match %r{\bChannels\b}, response.body
    assert_match %r{\b#{@rhn_cdn_advisory.packages.first.name}}, response.body
    assert_match %r{\bCDN file list metadata\b}, response.body
    assert_match %r{\bFTP Update Server\b}, response.body
  end

  test "push page shows archive details" do
    auth_as releng_user

    get :push_errata, :id => 19029
    assert_match %r{\bNon-RPMs\b}, response.body
    assert_match 'win/spice-usb-share-win-5.0-6-sources.zip', response.body
    assert_match 'images/rhel-server-x86_64-ec2-starter-6.5-8.x86_64.raw', response.body
    assert_match %r{# Non-RPM content:}, response.body
    assert_match '&quot;title&quot;=&gt;&quot;USB driver debugging info (64-bit)&quot;', response.body
  end

  test "cdn only advisory push closes bugs" do
    auth_as releng_user

    assert_difference('CdnPushJob.count') do
      post :push_errata_submit,
        :id => @cdn_advisory,
        :cdn_live => 1,
        :rhn_live => 0,
        :push_options_fields => {
        :cdn_push_job => @cdn_push_options
      }
    end
    assert_response :success

    push_job = CdnPushJob.last
    assert_same_push_tasks :post, @push_options, push_job
    assert_same_push_tasks :pre, @push_options,  push_job

    push_job.expects(:task_update_bugzilla).returns(true)
    push_job.pub_success!
  end

  test "cdn docker advisory push closes bugs" do
    auth_as releng_user

    advisory = Errata.find(21100)
    assert advisory.has_docker?
    assert_equal 'PUSH_READY', advisory.status

    assert_difference('PushJob.count', 2) do
      post :push_errata_submit,
        :id => advisory,
        :cdn_live => 1,
        :cdn_docker => 1,
        :rhn_live => 0,
        :push_options_fields => {
          :cdn_push_job => @cdn_push_options,
        }
    end
    assert_response :success

    cdn_push_job = CdnPushJob.last
    assert_same_push_tasks :post, @push_options, cdn_push_job
    assert_same_push_tasks :pre, @push_options,  cdn_push_job

    # If CDN (metadata) push job finishes first, bugs still closed
    Bugzilla::CloseBugJob.expects(:enqueue)
    cdn_push_job.pub_success!

    docker_push_job = CdnDockerPushJob.last
    docker_push_job.pub_success!
  end

  def assert_same_push_tasks(state, options, push_job)
    mandatory = LivePushTasks.const_get("#{state.to_s.upcase}_PUSH_TASKS").keys
    opts = options["#{state}_tasks"]
    refute opts.nil?, "Options empty for #{state}_tasks:\n#{options.inspect}\n\n"
    expected = opts.map { |k,v| k if v == "1" }.compact.append(mandatory).flatten
    actual = push_job.send("#{state}_push_tasks").sort
    assert expected.sort.join, actual.sort.join
  end

  test 'push rhn only' do
    rhn_cdn_push_test :errata => @rhn_advisory,
      :rhn => true,
      :rhn_live_options => @push_options,
      :matches => [/\bRhn Live\b/, /\bOk\b/],
      :no_matches => /\bCDN\b/
  end

  test 'push rhn only fail' do
    rhn_cdn_push_test :errata => @rhn_nopush_advisory,
      :rhn => true,
      :rhn_live_options => @push_options,
      :matches => /Can't push advisory to Rhn Live now due to: State QE invalid/,
      :no_matches => [/\bCDN\b/, /\bOk\b/i]
  end

  test 'can not select cdn live if advisory does not support it' do
    auth_as releng_user
    get :push_errata, :id => @rhn_advisory

    assert_response :success
    assert_no_match %r{\bCdn Live Push}, response.body
    assert_match    %r{\bRhn Live Push}, response.body
  end

  test 'push cdn only success' do
    rhn_cdn_push_test :errata => @cdn_advisory,
      :cdn => true,
      :cdn_live_options => @cdn_push_options,
      :matches => [/\bCDN\b/, /\bOk\b/],
      :no_matches => /\bRhn Live\b/
  end

  test 'can do cdn shadow push' do
    @cdn_advisory.release.class.any_instance.stubs(:allow_shadow? => true)

    assert_difference('CdnPushJob.count', 1) do
      rhn_cdn_push_test :errata => @cdn_advisory,
        :cdn => true,
        :cdn_live_options => {'options' => {'shadow' => 1}},
        :matches => [/\bCdn\b/, /\bOk\b/],
        :no_matches => /\bRhn Live\b/
    end

    # verify that it really was a shadow push
    job = CdnPushJob.last
    assert job.pub_options['shadow'], job.inspect
  end

  test 'cdn shadow push without allow_shadow on release will fail' do
    @cdn_advisory.release.class.any_instance.stubs(:allow_shadow? => false)

    assert_difference('CdnPushJob.count', 0) do
      rhn_cdn_push_test :errata => @cdn_advisory,
        :cdn => true,
        :cdn_live_options => {'options' => {'shadow' => 1}},
        :matches => [/\bCdn Live push FAILED\b/, /\bOption 'shadow' is not a valid option\b/],
        :no_matches => [/\bRhn Live\b/, /\bOk\b/]
    end
  end

  test 'push cdn only fail' do
    rhn_cdn_push_test :errata => @cdn_nopush_advisory,
      :cdn => true,
      :cdn_live_options => @cdn_push_options,
      :matches => /\bCan't push advisory to Cdn Live now due to: State QE invalid\b/,
      :no_matches => [/\bRhn Live\b/, /\bOk\b/i]
  end

  test 'can push altsrc' do
    do_push_test :errata => @rhn_cdn_advisory,
      :push_types => ['altsrc'],
      :matches => [/\bAltsrc\b/, /\bOk\b/]
  end

  test 'push rhn cdn' do
    rhn_cdn_push_test :errata => @rhn_cdn_advisory,
      :rhn => true,
      :cdn => true,
      :rhn_live_options => @push_options,
      :matches => [/\bRhn Live\b/, /\bCdn Live\b/, /\bOk\b/],
      :no_matches => /\bfailed\b/i
  end

  test 'push rhn cdn altsrc' do
    do_push_test :errata => @rhn_cdn_advisory,
      :push_types => %w[rhn_live cdn_live altsrc],
      :rhn_live_options => @push_options,
      :matches => [/\bRhn Live\b/, /\bCdn Live\b/, /\bAltsrc\b/, /\bOk\b/],
      :no_matches => /\bfailed\b/i
  end

  # If pushing both RHN and CDN, push tasks can be specified for both, and
  # will run for whichever finishes last.
  test 'push rhn cdn OK with tasks associated to both' do
    rhn_cdn_push_test :errata => @rhn_cdn_advisory,
      :rhn => true,
      :cdn => true,
      :rhn_live_options => @push_options,
      :cdn_live_options => @cdn_push_options,
      :matches => [/\bRhn Live\b/, /\bCdn Live\b/, /\bOk\b/],
      :no_matches => /\bfailed\b/i
  end

  test 'push rhn cdn fail' do
    rhn_cdn_push_test :errata => @rhn_cdn_nopush_advisory,
      :rhn => true,
      :cdn => true,
      :rhn_live_options => @push_options,
      :matches => [
        /\bCan't push advisory to Rhn Live now due to: State QE invalid\b/,
        /\bCan't push advisory to Cdn Live now due to: This errata cannot be pushed to RHN Live, thus may not be pushed to CDN\b/,
      ],
      :no_matches => /\bOk\b/i
  end

  test 'push rhn cdn to rhn only' do
    rhn_cdn_push_test :errata => @rhn_cdn_advisory,
      :rhn => true,
      :rhn_live_options => @push_options,
      :matches => [/\bRhn Live\b/, /\bOk\b/],
      :no_matches => [/\bCDN\b/, /\bfailed\b/i]
  end

  test 'push cdn and rhn stage success' do
    rhn_cdn_push_test :errata => @rhn_cdn_advisory,
      :cdn => true,
      :rhn => true,
      :stage => true,
      :options => {:push_immediately => '1'},
      :matches => [/\bRhn Stage\b/, /\bCdn Stage\b/, /\bOk\b/],
      :no_matches => /\bfailed\b/i
  end

  test 'push cdn stage failure' do
    rhn_cdn_push_test :errata => @rhn_cdn_nopush_advisory,
      :cdn => true,
      :stage => true,
      :options => {:push_immediately => '1'},
      :matches => [
        /\bCan't push advisory to Cdn Stage now due to\b/,
      ],
      :no_matches => /\bOk\b/i
  end

  # Bug 1127337 - Re-pushing CDN with no options does repo regeneration
  test 'push rhn cdn OK and skip pub task' do
    options = { "options" => {"push_files" => "0", "push_metadata" => "0"} }
    rhn_options = @push_options.dup.merge(options)
    cdn_options = @cdn_push_options.dup.merge(options)

    rhn_cdn_push_test :errata => @rhn_cdn_advisory,
      :rhn => true,
      :cdn => true,
      :rhn_live_options => rhn_options,
      :cdn_live_options => cdn_options,
      :matches => [
        /\bRhn live push job skipping pub; running post-push tasks only\b/,
        /\bCdn push job skipping pub; running post-push tasks only\b/
      ],
      :no_matches => /\bfailed\b/i
  end

  def rhn_cdn_push_test(args)
    stage_flag = args[:stage] ? 'stage' : 'live'

    push_types = []
    push_types << "rhn_#{stage_flag}" if args[:rhn]
    push_types << "cdn_#{stage_flag}" if args[:cdn]
    do_push_test(args.except(:rhn,:cdn).merge(:push_types => push_types))
  end

  def do_push_test(args)
    auth_as releng_user
    errata = args[:errata]
    matches = Array.wrap(args[:matches])
    no_matches = Array.wrap(args[:no_matches])

    params = {:id => errata}
    params.merge!(args.fetch(:options, {}))
    params[:stage]  = '1' if args[:stage]

    args[:push_types].each do |type|
      params[type] = '1'
      push_job = "#{type}_push_job"

      # kludge. push controller expects cdn_live => 1 if you want to push to non-stage CDN,
      # but uses cdn_push_job rather than cdn_live_push_job to look up the options.
      push_job = 'cdn_push_job' if push_job == 'cdn_live_push_job'

      (params[:push_options_fields] ||= {})[push_job] = args.fetch("#{type}_options".to_sym, {})
    end

    post :push_errata_submit, params

    body = response.body
    assert_response :success, body

    matches.each do |m|
      assert_match m, body, body
    end
    no_matches.each do |m|
      assert_no_match m, body, body
    end
  end

  test 'uncloseable JIRA issues do not cause push to fail' do
    issues = JiraIssue.where(:key => %w[HSSNAYENG-59 HSSCOMFUNC-551 HSSCOMFUNC-363]).order('id ASC').to_a
    assert_equal 3, issues.length

    issues.each do |iss|
      FiledJiraIssue.
        new(:jira_issue => iss, :errata => @rhn_advisory, :state_index => @rhn_advisory.current_state_index, :user => admin_user).
        save!(:validate => false)
    end

    client = Jira::Rpc.get_connection.class

    # It used to be checked whether issues can close during a pre-push
    # task, but the check is no longer expected
    client.any_instance.expects(:can_close_issue?).never

    @rhn_advisory.reload

    rhn_cdn_push_test :errata => @rhn_advisory,
      :rhn => true,
      :rhn_live_options => @push_options,
      :matches => /\bOk\b/,
      :no_matches => /failed/i
  end

  test "successfully shows push options for staging push" do
    auth_as releng_user

    get :push_errata,
      :id => @rhn_cdn_advisory,
      :stage => '1'
    assert_response :success
    assert_match %r{Rhn Stage}, response.body, response.body
    assert_match %r{Cdn Stage}, response.body, response.body
  end

  test "will not file ticket if ticket has already been filed" do
    auth_as admin_user
    job = mock('PushJob')
    job.expects(:problem_ticket_filed?).returns(true)
    PushJob.expects(:find).returns(job)

    post :file_pub_failure_ticket,
      :id => PushJob.last.id
    assert_match %r{already been filed}, flash[:alert]
  end

  test "files failure ticket" do
    auth_as admin_user

    notifier = mock('notifier')
    notifier.expects(:deliver)

    Notifier.expects(:file_pub_failure_ticket).returns(notifier)

    job = PushJob.last
    refute job.problem_ticket_filed?, "Need a job without a filed ticket for this test"

    post :file_pub_failure_ticket,
      :id => PushJob.last.id
    assert_match %r{ticket has been filed}, flash[:notice]
  end

  test 'errata oval' do
    auth_as devel_user
    # current time is used as a timestamp in oval output
    Time.stubs(:now => Time.gm(2012, 12, 12, 12, 12, 12))

    with_xml_baselines('errata_oval_baseline', /errata-(\d+)\.xml$/) do |_, id|
      get :oval, :id => id
      assert_response :success, response.body
      response.body
    end
  end

  test 'errata oval with jira as references' do
    auth_as devel_user
    Settings.jira_as_references = true

    # current time is used as a timestamp in oval output
    Time.stubs(:now => Time.gm(2012, 12, 12, 12, 12, 12))

    with_xml_baselines('errata_oval_baseline', /errata-jiraref-(\d+)\.xml$/) do |_, id|
      get :oval, :id => id
      assert_response :success, response.body
      response.body
    end
  end

  #
  # Returns an RhnLivePushJob, which can be pushed to pub
  #
  def get_push_job
    job = RhnLivePushJob.create!(:errata => @rhn_cdn_advisory, :pushed_by => releng_user)
    job.pub_options['push_metadata'] = true
    job.pub_options['push_files'] = true
    job
  end

  #
  # Returns a pub client mock, with :submit_push_job stubbed out in
  # order to push to pub.
  #
  def get_pub_client
    mockpub = mock('Push::Pub')
    mockpub.expects(:submit_push_job).returns(123)
    Push::PubClient.stubs(:get_connection).returns(mockpub)
    mockpub
  end

  test 'user is able to update push job' do
    auth_as releng_user

    #
    # Setup a push job and fake that is being pushed to pub. The
    # successful push to pub creates a Delayed::Job PubWatcher. The controller method
    # queries for it and invokes the Delayed Job.
    #
    # The mocks are simulating a positive case from pub.
    #
    mockpub = get_pub_client
    mockpub.expects(:get_tasks).returns([{"is_finished"=>true, "id"=>123, "is_failed"=>false}])

    job = get_push_job
    job.create_pub_task(mockpub)
    PushJob.expects(:for_pub_task).returns([job])

    post :update_job_status, :id => job
    assert_redirected_to :action => :push_results, :id => job
    assert_match %r{Running post push}, job.log
  end

  test 'update push job button not available if job is not in waiting status' do
    auth_as releng_user
    job = get_push_job

    get :push_results, :id => job
    assert_response :success

    assert_no_match %r{\bCheck status now\b}, response.body
    assert_match %r{\bStop job\b}, response.body
  end

  test 'update push job button available during WAITING_ON_PUB status' do
    auth_as releng_user
    job = get_push_job
    job.create_pub_task(get_pub_client)

    get :push_results, :id => job
    assert_response :success

    assert_match %r{\bCheck status now\b}, response.body
  end

  # error messages may be generated in push failure cases; not otherwise
  assert_no_error_logs instance_methods.grep(/^test/).reject{|fn| fn =~ /fail$/}

  # bug 1130063
  test 'push skipping pub should not move to SHIPPED_LIVE when no previous committed push' do
    auth_as releng_user

    e = Errata.find(11110)
    assert_equal 'PUSH_READY', e.status, 'fixture problem: expected to begin at PUSH_READY'

    assert_difference(['RhnLivePushJob.count', 'Delayed::Job.count'], 1) do
      post :push_errata_submit,
        :id => e.id,
        :rhn_live => 1,
        :push_options_fields => {
          :rhn_live_push_job => {
            # having push options blank should skip any pub task, but
            # still do some post-push task.
            :options => {},
            :post_tasks => {
              :move_pushed_errata => 1
            }
          }
        }
    end
    assert_response :success

    push_job = RhnLivePushJob.last
    assert_equal e.reload, push_job.errata

    # should not have created any pub task
    assert_nil push_job.pub_task_id

    # the post-push tasks are run as a delayed job
    dj = Delayed::Job.last

    dj.invoke_job

    # push job should be finished, but advisory status unchanged
    assert_equal 'COMPLETE', push_job.reload.status
    assert_equal 'PUSH_READY', e.reload.status

    # and the log explains why
    assert_match "Advisory shouldn't move to SHIPPED_LIVE because rhn_live push is not complete", push_job.log
  end

  test 'push skipping pub should move to SHIPPED_LIVE if push previously committed' do
    auth_as releng_user

    # This should be the scenario mentioned in bug 1130063.  Advisory
    # was pushed to pub, but some post-push task failed.  Now it's
    # desired just to re-run post-push tasks and move advisory to
    # SHIPPED_LIVE.
    e = Errata.find(19032)

    # It has an RhnLivePushJob, but it stalled in post-push tasks
    assert_equal ['POST_PUSH_PROCESSING'], RhnLivePushJob.for_errata(e).map(&:status)

    assert_difference(['RhnLivePushJob.count', 'Delayed::Job.count'], 1) do
      post :push_errata_submit,
        :id => e.id,
        :rhn_live => 1,
        :push_options_fields => {
          :rhn_live_push_job => {
            :options => {},
            :post_tasks => {
              :move_pushed_errata => 1
            }
          }
        }
    end
    assert_response :success

    push_job = RhnLivePushJob.last
    assert_equal e.reload, push_job.errata

    # should not have created any pub task
    assert_nil push_job.pub_task_id

    # the post-push tasks are run as a delayed job
    Delayed::Job.last.invoke_job

    # push job should be finished, and advisory now shipped
    assert_equal 'COMPLETE', push_job.reload.status
    assert_equal 'SHIPPED_LIVE', e.reload.status
  end

  # Test RHN & CDN together because that has an impact on whether
  # post-push tasks are allowed to run.
  test 'tasks-only push for RHN and CDN together runs tasks as expected' do
    auth_as releng_user

    e = Errata.find(16616)

    assert e.can_push_rhn_live?
    assert e.can_push_cdn_if_live_push_succeeds?
    assert_equal [], e.push_jobs.where(:type => %w[CdnPushJob RhnLivePushJob]).to_a

    assert_difference(['RhnLivePushJob.count', 'CdnPushJob.count'], 1) do
      assert_difference('Delayed::Job.count', 2) do
        push_job_input = {
          :options => {},
          :post_tasks => {
            :move_pushed_errata => 1,
            :update_bugzilla => 1,
            :update_jira => 1,
          }
        }
        post :push_errata_submit,
          :id => e.id,
          :rhn_live => 1,
          :cdn_live => 1,
          :push_options_fields => {
            :rhn_live_push_job => push_job_input,
            :cdn_push_job => push_job_input.dup,
          }
        assert_response :success, response.body
      end
    end

    rhn_pj = RhnLivePushJob.order('id desc').first
    cdn_pj = CdnPushJob.order('id desc').first
    dj = Delayed::Job.order('id desc').limit(2)
    rhn_dj = dj.where('handler like "%RhnLivePushJob%"').first
    cdn_dj = dj.where('handler like "%CdnPushJob%"').first

    # Both should be ready to do post-push processing
    [rhn_pj, cdn_pj].each do |job|
      assert_equal 'POST_PUSH_PROCESSING', job.status, "job #{job.inspect}"
    end

    # The post-push tasks should be executed by whichever job is
    # handled first...
    cdn_dj.invoke_job

    check_job = lambda do |job|
      # It should have completed, and really run the tasks, and not
      # moved to SHIPPED_LIVE since there's no committed push using
      # pub.
      assert_equal 'COMPLETE', job.reload.status
      assert_match "Advisory shouldn't move to SHIPPED_LIVE because rhn_live, cdn push is not complete", job.log
      assert_match 'Calling move-pushed-erratum', job.log
    end
    check_job.call(cdn_pj)

    # Now the RHN delayed job is run...
    rhn_dj.invoke_job

    # And the RHN push job is complete too.  Note that it reruns the
    # same push tasks as previously run for CDN.  That's useless but
    # also harmless.
    check_job.call(rhn_pj)
  end

  test 'push cdn_docker only success' do
    do_push_test :errata => Errata.find(21100),
      :cdn_docker => true,
      :cdn_docker_options => {},
      :matches => [/\bCdn docker\b/, /\bOk\b/],
      :no_matches => /\bRhn Live\b/,
      :push_types => [:cdn_docker]
  end

end
