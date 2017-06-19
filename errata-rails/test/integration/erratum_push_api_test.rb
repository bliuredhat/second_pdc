require 'test_helper'

class ErratumPushApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as releng_user
  end

  test 'index baseline test' do
    with_baselines('api/v1/erratum_push/index', %r{errata_(\d+).json$}) do |file,id|
      get "/api/v1/erratum/#{id}/push"
      formatted_json_response
    end
  end

  test 'show baseline test' do
    with_baselines('api/v1/erratum_push/show', %r{push_(\d+)_(\d+).json$}) do |file,erratum_id,id|
      get "/api/v1/erratum/#{erratum_id}/push/#{id}"
      formatted_json_response
    end
  end

  # This test only tests various error cases.
  #
  # Testing a successful push isn't a baseline test since the returned
  # value is not static.
  test 'push with default options baseline test' do
    with_baselines('api/v1/erratum_push/create', %r{errata_(\d+)_(.*)\.json$}) do |filename,id,targets|
      targets = targets.split(',')
      pushdata = targets.map{|tgt| {'target' => tgt}}
      if pushdata.length == 1
        pushdata = pushdata.first
      end

      assert_no_difference('PushJob.count', "Incorrectly created push job for #{filename}") {
        post_json "/api/v1/erratum/#{id}/push", pushdata
      }
      formatted_json_response
    end
  end

  def push_fail_test(filename, opts = {})
    e = opts.delete(:errata) || Errata.find(16374)

    url = "/api/v1/erratum/#{e.id}/push"
    if q = opts.delete(:query)
      url += "?#{q}"
    end

    pushdata = opts.include?(:pushdata) \
      ? opts.delete(:pushdata) \
      : {:target => 'cdn'}

    assert_no_difference('PushJob.count') {
      post_json url, pushdata
    }
    assert_testdata_equal(filename, formatted_json_response)
  end

  test 'push failure when not logged in' do
    logout
    push_fail_test('api/v1/erratum_push/create/fail_no_auth.json')
  end

  test 'push failure when logged in without appropriate role' do
    auth_as devel_user
    push_fail_test('api/v1/erratum_push/create/fail_missing_role.json')
  end

  test 'push failure when specifying nonexistent options' do
    push_fail_test('api/v1/erratum_push/create/fail_bad_options.json',
      :pushdata => {:target => 'cdn', :options => %w[foo bar]})
  end

  test 'push failure when specifying nonexistent pre-push tasks' do
    push_fail_test('api/v1/erratum_push/create/fail_bad_pre_tasks.json',
      :pushdata => {:target => 'cdn', :pre_tasks => %w[foo bar]})
  end

  test 'push failure when specifying nonexistent post-push tasks' do
    push_fail_test('api/v1/erratum_push/create/fail_bad_post_tasks.json',
      :pushdata => {:target => 'cdn', :post_tasks => %w[foo bar]})
  end

  test 'push failure when specifying bad defaults' do
    push_fail_test('api/v1/erratum_push/create/fail_bad_defaults.json',
      :pushdata => nil, :query => 'defaults=frobnitz')
  end

  test 'push failure when including push targets with defaults' do
    push_fail_test('api/v1/erratum_push/create/fail_defaults_and_pushdata.json',
      :query => 'defaults=live')
  end

  test 'push failure when specifying defaults=live on not-live-ready advisory' do
    push_fail_test('api/v1/erratum_push/create/fail_bad_stage_defaults.json',
      :errata => Errata.find(11118), :pushdata => nil, :query => 'defaults=live')
  end

  test 'push does nothing when specifying defaults with no available targets' do
    RHEA.any_instance.stubs(:supported_push_types => [])
    push_fail_test('api/v1/erratum_push/create/push_defaults_no_targets.json',
      :pushdata => nil, :query => 'defaults=live')
  end

  test 'can do single push' do
    e = Errata.find(10836)

    # get a default job for later comparison
    default_job = default_job(RhnLivePushJob, :errata => e, :pushed_by => releng_user)

    assert_difference('RhnLivePushJob.count', 1) {
      post_json "/api/v1/erratum/#{e.id}/push", {:target => 'rhn_live'}
      assert_response :success, response.body
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_single_rhn_live.json',
      cleaned_formatted_json_response
    )

    # sanity check that the job really matches what the response said
    data = JSON.load(response.body)
    assert_equal 1, data.length
    job = RhnLivePushJob.last
    %w[id status].each do |key|
      assert_equal job.send(key), data[0][key], "mismatch on #{key}"
    end

    # options/tasks were omitted, so it should have used the defaults.
    # Compare against result of set_defaults rather than hardcoding
    # the values.
    assert_equal(default_job.pub_options,     job.pub_options)
    assert_equal(default_job.pre_push_tasks,  job.pre_push_tasks)
    assert_equal(default_job.post_push_tasks, job.post_push_tasks)
  end

  test 'can do multi-target push' do
    e = Errata.find(10836)

    assert_difference('RhnLivePushJob.count', 1) {
      assert_difference('CdnPushJob.count', 1) {
        post_json "/api/v1/erratum/#{e.id}/push", [
          {:target => 'rhn_live'},
          {:target => 'cdn'}
        ]
        assert_response :success, response.body
      }
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_cdn_and_rhn_live.json',
      cleaned_formatted_json_response
    )

    # sanity check that the jobs really match what the response said.
    # Note that the API is also expected to return the result objects in
    # the same order as the input objects, so RHN is first, CDN second.
    data = JSON.load(response.body)
    assert_equal 2, data.length

    jobs = [RhnLivePushJob.last ,CdnPushJob.last]
    jobs.each_with_index do |job,idx|
      %w[id status].each do |key|
        assert_equal job.send(key), data[idx][key], "mismatch on #{job.class} #{key}"
      end
    end
  end

  test 'can do staging push' do
    e = Errata.find(11118)

    assert_difference('RhnStagePushJob.count', 1) {
      assert_difference('CdnStagePushJob.count', 1) {
        post_json "/api/v1/erratum/#{e.id}/push", [
          {:target => 'rhn_stage'},
          {:target => 'cdn_stage'},
        ]
        assert_response :success, response.body
      }
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_cdn_and_rhn_stage.json',
      cleaned_formatted_json_response
    )
  end

  test 'docker staging push' do
    e = Errata.find(21101)

    # Pre-requisites for docker staging push
    DockerMetadataRepoList.create(:errata => e)
    e.docker_metadata_repo_list.set_cdn_repos_by_id([21])
    e.docker_metadata_repo_list.save!
    e.change_state!('QE', qa_user)

    assert_difference('CdnStagePushJob.count', 1) {
      assert_difference('CdnDockerStagePushJob.count', 1) {
        post_json "/api/v1/erratum/#{e.id}/push", [
          {:target => 'cdn_stage'},
          {:target => 'cdn_docker_stage'},
        ]
        assert_response :success, response.body
      }
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_cdn_docker_stage.json',
      cleaned_formatted_json_response
    )
  end

  test 'can do default stage push' do
    e = Errata.find(11118)

    # RHN stage already pushed, won't be re-pushed
    assert_no_difference('RhnStagePushJob.count') {
      assert_difference('CdnStagePushJob.count', 1) {
        post_json "/api/v1/erratum/#{e.id}/push?defaults=stage", nil
        assert_response :success, response.body
      }
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_defaults_stage.json',
      cleaned_formatted_json_response
    )
  end

  test 'can do default live push' do
    e = Errata.find(10836)

    assert_difference('PushJob.count', 3) do
      assert_difference(%w[
        RhnLivePushJob.count
        CdnPushJob.count
        FtpPushJob.count
      ], 1) do
        post_json "/api/v1/erratum/#{e.id}/push?defaults=live", nil
        assert_response :success, response.body
      end
    end

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_defaults_live.json',
      cleaned_formatted_json_response
    )
  end

  test 'can do default live push on an advisory where some target is restricted' do
    e = Errata.find(19030)
    assert(e.supports_rhn_live? && !e.has_rhn_live?,
      'fixture problem: advisory is expected to support RHN but skip it due to package restrictions')

    assert_difference('PushJob.count', 3) do
      assert_difference(%w[
        CdnPushJob.count
        FtpPushJob.count
        AltsrcPushJob.count
      ], 1) do
        post_json "/api/v1/erratum/#{e.id}/push?defaults=live", nil
        assert_response :success, response.body
      end
    end

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_defaults_live_with_restriction.json',
      cleaned_formatted_json_response
    )
  end

  test 'default live push skips FTP and Altsrc for text-only advisory' do
    e = Errata.find(16616)
    assert e.text_only?, 'testdata problem'

    assert_difference('PushJob.count', 2) do
      assert_difference(%w[
        RhnLivePushJob.count
        CdnPushJob.count
      ], 1) do
        post_json "/api/v1/erratum/#{e.id}/push?defaults=live", nil
        assert_response :success, response.body
      end
    end

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_defaults_live_textonly.json',
      cleaned_formatted_json_response
    )
  end

  test 'default live push skips already pushed' do
    e = Errata.find(10836)

    # simulate that RHN has completely pushed, CDN has tried but failed
    rhn_job = default_job(RhnLivePushJob, :errata => e, :pushed_by => releng_user)
    rhn_job.save!
    rhn_job.pub_success!

    cdn_job = default_job(CdnPushJob, :errata => e, :pushed_by => releng_user)
    cdn_job.save!
    cdn_job.mark_as_failed!('Simulated pub failure')

    # it should redo CDN push, and it should do FTP push for
    # the first time.  It should not redo RHN push.
    assert_difference('PushJob.count', 2) do
      post_json "/api/v1/erratum/#{e.id}/push?defaults=live", nil
      assert_response :success, response.body
    end

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_defaults_live_have_failed.json',
      cleaned_formatted_json_response
    )
  end

  test 'default live push skips in progress' do
    e = Errata.find(10836)

    # simulate that RHN, CDN, FTP are currently pushing
    [RhnLivePushJob,CdnPushJob,FtpPushJob].each do |klass|
      default_job(klass, :errata => e, :pushed_by => releng_user).save!
    end

    assert_no_difference('PushJob.count') do
      post_json "/api/v1/erratum/#{e.id}/push?defaults=live", nil
      assert_response :success, response.body
    end

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_defaults_no_targets.json',
      cleaned_formatted_json_response
    )
  end

  test 'skip options are applied to target' do
    e = Errata.find(19030)

    assert e.push_jobs.where(:type => 'CdnPushJob').empty?

    assert_difference('CdnPushJob.count') do
      post_json "/api/v1/erratum/#{e.id}/push", {:target => 'cdn'}
      assert_response :success, response.body
    end

    # We should now have a job, submitted to pub
    job = CdnPushJob.last
    assert_equal e.id, job.errata_id
    assert_not_nil job.pub_task_id

    # If we ask to push again, it should fail...
    assert_no_difference('PushJob.count') do
      post_json "/api/v1/erratum/#{e.id}/push", {:target => 'cdn'}
      assert_response :bad_request, response.body
    end

    # ...since it was already running
    data = JSON.load(response.body)
    cdn_errors = data['errors']['cdn'].join
    assert_match 'is already running', cdn_errors

    # But if we pass skip_in_progress, the target will be stripped
    assert_no_difference('PushJob.count') do
      post_json "/api/v1/erratum/#{e.id}/push", {:target => 'cdn',
                                                 :skip_in_progress => true}
      assert_response :success, response.body
    end

    # It should not have created any push job
    assert_equal [], JSON.load(response.body)

    # Now, if the job has finished...
    job.pub_success!

    # Skip pushed should, again, create no job
    assert_no_difference('PushJob.count') do
      post_json "/api/v1/erratum/#{e.id}/push", {:target => 'cdn',
                                                 :skip_pushed => true}
      assert_response :success, response.body
    end
    assert_equal [], JSON.load(response.body)

    # Removing the skip option should allow it to repush CDN
    assert_difference('CdnPushJob.count') do
      post_json "/api/v1/erratum/#{e.id}/push", {:target => 'cdn'}
      assert_response :success, response.body
    end

    new_job = CdnPushJob.last
    assert_equal e.id, new_job.errata_id
    assert_not_nil new_job.pub_task_id
  end

  # What this is really testing is that options/tasks are parsed
  # correctly. Shadow push is just one major use-case for that.
  test 'can do shadow push' do
    e = Errata.find(10836)
    e.release.update_attributes!(:allow_shadow => true)

    assert_difference('RhnLivePushJob.count', 1) {
      post_json "/api/v1/erratum/#{e.id}/push", [{
        :target => 'rhn_live',
        :options => %w[shadow],
        :pre_tasks => %w[set_issue_date],
        :post_tasks => %w[],
      }]
      assert_response :success, response.body
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_shadow_rhn_live.json',
      cleaned_formatted_json_response
    )

    # verify the options/tasks really made it through
    job = RhnLivePushJob.last
    assert_equal(
      {'push_metadata' => true, 'shadow' => true, 'push_files' => true},
      job.pub_options)

    # in both cases, we got more tasks than we requested,
    # because mandatory tasks are always included
    assert_equal(%w[set_in_push set_issue_date set_live_id set_update_date],
      job.pre_push_tasks.sort)

    assert_equal(%w[check_error mark_errata_shipped update_push_count],
      job.post_push_tasks.sort)
  end

  # This tests passing an options hash, rather than an array of
  # boolean-only options.
  test 'can do metadata-only push' do
    e = Errata.find(10836)

    assert_difference('RhnLivePushJob.count', 1) {
      post_json "/api/v1/erratum/#{e.id}/push", {
        :target => 'rhn_live',
        :options => {:push_metadata => true, :push_files => false, :priority => 80}
      }
      assert_response :success, response.body
    }

    assert_testdata_equal(
      'api/v1/erratum_push/create/push_metadata_rhn_live.json',
      cleaned_formatted_json_response
    )

    job = RhnLivePushJob.last
    assert_equal(
      {'push_metadata' => true, 'push_files' => false, 'priority' => 80},
      job.pub_options)
  end

  test 'pub tasks are submitted outside of any transaction' do
    e = Errata.find(10836)

    # We replace transaction method with our own method which sets up
    # mocha expectations so that:
    # - upon entering a non-nested transaction, submit! is expected never to be called
    # - upon exiting a non-nested transaction, submit! is expected to be called once
    in_transaction = 0
    transaction_spy = lambda do |&block|
      begin
        if in_transaction == 0
          RhnLivePushJob.any_instance.expects(:submit!).never
        end
        in_transaction += 1
        block.call()
      ensure
        in_transaction -= 1
        if in_transaction == 0
          RhnLivePushJob.any_instance.expects(:submit!).times(1)
        end
      end
    end

    self.class.with_replaced_method(ActiveRecord::Base, :transaction, transaction_spy) do
      assert_difference('RhnLivePushJob.count', 1) {
        post_json "/api/v1/erratum/#{e.id}/push", {:target => 'rhn_live'}
        assert_response :success, response.body
      }
    end
  end

  # Like formatted_json_response, but wipes out certain unpredictable
  # fields from the response, e.g. fields which contain IDs or
  # timestamps whose value can't directly be compared in baseline
  # tests.
  def cleaned_formatted_json_response
    clean_hash = lambda do |x|
      x = x.dup

      # considered filtering pub_task ID too, but the result should be
      # stable - should only change if MAX(pub_task_id) in fixtures
      # changes
      %w[id log url].each do |key|
        if x.include?(key)
          x[key] = "<some #{key}>"
        end
      end

      x
    end

    clean = lambda do |x|
      if x.kind_of?(Hash)
        clean_hash.call(x)
      else
        x.map(&clean_hash)
      end
    end

    formatted_json_response(:transform => clean)
  end

  # Creates and returns a default initialized job of the specified
  # class and attributes.  The job is not persisted, but has all the
  # usual validation/callbacks done. Useful to compare attributes with
  # a newly created job.
  def default_job(klass, attributes)
    out = nil
    ActiveRecord::Base.transaction do
      out = klass.new(attributes)
      out.set_defaults
      # Must always have some associated pub task, otherwise the job
      # is considered to not have really performed a push, which
      # affects some logic.
      out.pub_task_id = PushJob.pluck('max(pub_task_id)').first + 100
      out.save!
      raise ActiveRecord::Rollback
    end
    out
  end

end
