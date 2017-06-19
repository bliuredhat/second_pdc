require 'test_helper'

class PushApiTest < ActionDispatch::IntegrationTest

  API = 'api/v1/push'

  # Only using fixture records up to this one, to keep the test stable if new
  # fixtures are introduced
  MAX_JOB = 47310
  MAX_ERRATA = 20836

  setup do
    auth_as releng_user

    # For predictable push logs.
    Time.stubs(:now => Time.utc(2016, 2, 10))
  end

  test 'index baseline' do
    PushJob.with_scope(:find => {:conditions => ['push_jobs.id <= ?', MAX_JOB], order: :id}) do
      with_baselines(API, %r{\/index(?:_(.+))?\.json$}) do |_, params|
        get [API, params].join('?')
        formatted_json_response
      end
    end
  end

  test 'show baseline' do
    with_baselines(API, %r{\/show_(.+)\.json$}) do |_, params|
      get [API, params].join('/')
      formatted_json_response
    end
  end

  test 'push with garbage targets' do
    post_json "#{API}?filter[release_name]=RHEL-6.1.0",
              [{'target' => 'foo'},
               {'target' => 'bar'}]
    assert_push_response_equal('push_bad_targets')
  end

  test 'push with too broad filter' do
    # API complains if not filtering by batch or release.  This is an
    # intentional safeguard against pushing too much.
    post "#{API}?defaults=live"
    assert_push_response_equal('push_bad_filter')

    # (filtering by other things is not good enough)
    post "#{API}?defaults=live&filter[errata_status]=PUSH_READY"
    assert_push_response_equal('push_bad_filter')
  end

  test 'push with bad target spec' do
    # in this request, there is one valid push target specifier and one
    # forgetting to specify the target
    post_json "#{API}?filter[release_name]=RHEL-6.1.0",
              [{'target' => 'rhn_live'},
               {'options' => ['foo']}]
    assert_push_response_equal('push_missing_target')
  end

  test 'push with bad filter values' do
    do_test = lambda do |key, *values|
      query = values.map do |v|
        "filter[#{key}][]=#{v}"
      end.join('&')

      assert_no_difference('PushJob.count') do
        post_json "#{API}?#{query}", {'target' => 'rhn_stage'}
        assert_push_response_equal("push_bad_filter_#{key}")
      end
    end

    do_test['errata_name', Errata.first.fulladvisory, 'bad1', 'bad2']
    do_test['errata_id', Errata.first.id, 88888888]
    do_test['errata_status', 'QE', 'REL_PREP', 'bad1', 'bad2']
    do_test['release_name', Release.first.name, 'bad1', 'bad2']
    do_test['release_id', 88888888]
    do_test['batch_name', Batch.first.name, 'notexist']
    do_test['batch_id', 88888888, 88888889, Batch.first.id]
  end

  test 'push a release' do
    EXPECTED_JOB_COUNT = 12

    Errata.with_scope(:find => {:conditions => ['errata_main.id <= ?', MAX_ERRATA]}) do
      # Save the errata we expect to operate on, for later processing
      errata = Release.find_by_name!('RHEL-6.1.0').errata.
               where(:status => %w[PUSH_READY IN_PUSH SHIPPED_LIVE]).to_a

      # This is a typical use-case:
      # Trigger live push for an entire release.
      assert_difference('PushJob.count', EXPECTED_JOB_COUNT) do
        post "#{API}?filter[release_name]=RHEL-6.1.0&defaults=live", nil
        assert_response :success, response.body
      end

      assert_push_response_equal('push_release_live')

      # If we try it again, it should succeed but not do anything since they're
      # all already in progress
      assert_no_difference('PushJob.count') do
        post "#{API}?filter[release_name]=RHEL-6.1.0&defaults=live", nil
        assert_response :success, response.body
      end

      assert_push_response_equal('empty')

      # Check the created jobs.
      jobs = PushJob.order('id desc').limit(EXPECTED_JOB_COUNT).to_a

      # Should be live types only, as requested
      assert_equal %w[AltsrcPushJob CdnPushJob FtpPushJob RhnLivePushJob],
                   jobs.map(&:type).uniq.sort

      # All should be for RHEL-6.1.0 as requested
      assert_equal ['RHEL-6.1.0'], jobs.map{ |j| j.errata.release.name }.uniq

      # They should not have pub tasks created yet (that would be handled by a
      # background job)
      assert_equal [nil], jobs.map(&:pub_task_id).uniq

      # Check expected postcondition of the API: every errata at PUSH_READY or
      # later should have an active or completed push job now.
      errata.each do |e|
        not_failed_jobs = e.push_jobs.where('status != "FAILED"').map(&:type)
        if e.has_cdn?
          assert not_failed_jobs.include?('CdnPushJob')
        end
        if e.has_rhn_live?
          assert not_failed_jobs.include?('RhnLivePushJob')
        end
        if e.has_ftp?
          assert not_failed_jobs.include?('FtpPushJob')
        end
        if e.has_altsrc?
          assert not_failed_jobs.include?('AltsrcPushJob')
        end
      end
    end
  end

  test 'push batch with status' do
    batch = Batch.find(4)

    # starts out with nothing
    assert batch.errata.empty?

    Errata.with_scope(:find => {:conditions => ['errata_main.id <= ?', MAX_ERRATA]}) do
      batch.release.errata.new_files.each do |e|
        e.batch = batch
        e.save!
      end

      # Initially, it will do nothing - errata in the batch are not in a valid
      # status for these targets, and thus are filtered by default
      assert_no_difference('PushJob.count') do
        post_json "#{API}?filter[batch_id]=4", [{'target' => 'cdn'},
                                                {'target' => 'rhn_stage'}]
        assert_push_response_equal('empty')
      end

      # If we now explicitly specify NEW_FILES errata, we should be told that's
      # illegal for both targets
      assert_no_difference('PushJob.count') do
        post_json "#{API}?filter[batch_id]=4&filter[errata_status]=NEW_FILES",
                  [{'target' => 'cdn'},
                   {'target' => 'rhn_stage'}]
        assert_push_response_equal('push_batch4_bad_status_1')
      end

      # If we have REL_PREP errata instead, we should be able to push to stage, but
      # not live
      batch.release.errata.rel_prep.each do |e|
        e.batch = batch
        e.save!
      end

      assert_no_difference('PushJob.count') do
        post_json "#{API}?filter[batch_id]=4&filter[errata_status]=REL_PREP",
                  [{'target' => 'cdn'},
                   {'target' => 'rhn_stage'}]
        assert_push_response_equal('push_batch4_bad_status_2')
      end

      # Explicitly pushing stage only should work, regardless of whether or not
      # errata_status is provided, since it'll automatically filter on
      # appropriate status for stage.  (Use dryrun to compare the two)
      assert_no_difference('PushJob.count') do
        post_json "#{API}?filter[batch_id]=4&dryrun=1", {'target' => 'rhn_stage'}
        assert_push_response_equal('push_batch4_stage_dryrun')

        post_json "#{API}?filter[batch_id]=4&filter[errata_status]=REL_PREP&dryrun=1",
                  {'target' => 'rhn_stage'}
        assert_push_response_equal('push_batch4_stage_dryrun')
      end

      # Do it for real...
      assert_difference('PushJob.count', 3) do
        assert_difference('RhnStagePushJob.count', 3) do
          post_json "#{API}?filter[batch_id]=4", {'target' => 'rhn_stage'}
          assert_push_response_equal('push_batch4_stage')
        end
      end
    end
  end

  test 'stage push a release' do
    EXPECTED_COUNT = 2

    # This test incidentally checks that the API queues submitting the push jobs
    # (which is otherwise not tested by integration tests)
    PushJob.expects(:submit_jobs_later).with do |jobs|
      assert_equal EXPECTED_COUNT,    jobs.length
      assert_equal [RhnStagePushJob], jobs.map(&:class).uniq
      true
    end

    assert_difference('PushJob.count', EXPECTED_COUNT) do
      assert_difference('RhnStagePushJob.count', EXPECTED_COUNT) do
        post "#{API}?filter[release_name]=ASYNC&filter[errata_status]=REL_PREP&defaults=stage"
        assert_push_response_equal('push_async_stage')
      end
    end
  end

  test 'push specific errata' do
    assert_difference('PushJob.count', 2) do
      assert_difference('RhnStagePushJob.count', 2) do
        post "#{API}?filter[errata_id][]=11138&filter[errata_id][]=11133&defaults=stage"
        # deliberately chose the same errata as above case
        assert_push_response_equal('push_async_stage')
      end
    end
  end

  test 'attempt pre-push with embargoed bugs' do
    assert_no_difference('PushJob.count') do
      post_json "#{API}?filter[errata_id]=11133&filter[errata_status]=REL_PREP", [
        {'target' => 'cdn', 'options' => %w(nochannel push_metadata)},
        {'target' => 'rhn_live', 'options' => %w(nochannel push_metadata)},
      ]
      assert_push_response_equal('prepush_embargoed_bugs')
    end
  end

  test 'push cdn then rhn' do
    # Due to CDN requiring RHN to be pushed earlier or together, there's special
    # code needed to make this work when the caller specified CDN target earlier
    # than RHN target. That's why this testcase exists.
    assert_difference('RhnLivePushJob.count', 1) do
      assert_difference('CdnPushJob.count', 1) do
        force_sync_delayed_jobs do
          post_json "#{API}?filter[errata_id]=19029", [
            {'target' => 'cdn'},
            {'target' => 'rhn_live'},
          ]
        end
        assert_push_response_equal('push_cdn_rhn')
      end
    end

    # The jobs should have been able to submit OK as well...
    assert_equal 'WAITING_ON_PUB', RhnLivePushJob.last.status
    assert_equal 'WAITING_ON_PUB', CdnPushJob.last.status
  end

  test 'push nochannel bad tasks' do
    e = nochannel_push_errata

    assert_no_difference('RhnLivePushJob.count') do
      assert_no_difference('CdnPushJob.count') do
        post_json "#{API}?filter[errata_id]=#{e.id}&filter[errata_status]=#{e.status}", [
          {'target' => 'cdn', 'options' => %w(nochannel push_files)},
          # trying both options syntax
          {'target' => 'rhn_live', 'options' => {'nochannel' => true,
                                                 'push_files' => true}},
        ]
        assert_push_response_equal('push_nochannel_bad_tasks')
      end
    end
  end

  test 'push nochannel bad options' do
    e = nochannel_push_errata

    assert_no_difference('RhnLivePushJob.count') do
      post_json("#{API}?filter[errata_id]=#{e.id}&filter[errata_status]=#{e.status}",
                # In this request, since push_files/push_metadata aren't present,
                # this nochannel push would skip pub and run tasks only, which doesn't
                # make sense.
                {'target' => 'cdn',
                 'options' => ['nochannel'],
                 'pre_tasks' => [],
                 'post_tasks' => []})
      assert_push_response_equal('push_nochannel_bad_options')
    end
  end

  test 'push nochannel' do
    e = nochannel_push_errata

    tasks = {'pre_tasks' => [],
             'post_tasks' => []}
    cdn = {'target' => 'cdn', 'options' => %w(push_files nochannel)}.merge(tasks)
    rhn = {'target' => 'rhn_live',
           'options' => {'nochannel' => true, 'push_files' => true}}.merge(tasks)

    pub_client = Push::DummyClient.any_instance
    pub_client.expects(:submit_push_job).with(is_a(RhnLivePushJob)).once.returns(888888)
    pub_client.expects(:submit_push_job).with(is_a(CdnPushJob)).once.returns(888889)

    # doing synchronous pub submission here to test the full stack down to pub client
    force_sync_delayed_jobs do
      assert_difference('RhnLivePushJob.count', 1) do
        assert_difference('CdnPushJob.count', 1) do
          post_json("#{API}?filter[errata_id]=#{e.id}&filter[errata_status]=#{e.status}",
                    [cdn, rhn])
          assert_push_response_equal('push_nochannel')
        end
      end
    end

    [[RhnLivePushJob, 888888],
     [CdnPushJob,     888889]].each do |klass, task_id|
      pj = klass.last
      message = "failed for #{klass}"

      assert_equal e.id, pj.errata_id, message
      assert pj.pub_options['nochannel'], message

      # Should have selected no pre/post tasks as well
      assert_equal [], pj.pre_push_tasks, message
      assert_equal [], pj.post_push_tasks, message

      # The log should explain this is a nochannel push
      assert_match 'Note: this is a nochannel push', pj.log

      # Should be submitted to pub
      assert_equal task_id, pj.pub_task_id
      assert_equal 'WAITING_ON_PUB', pj.status
    end
  end

  def nochannel_push_errata
    Errata.find(19463).tap do |e|
      # This is an advisory which is not pushed yet, is not in a valid state
      # for "normal" live pushes but is in a valid state for nochannel
      # pushes, and supports RHN/CDN
      assert_equal 'REL_PREP', e.status
      assert e.supports_rhn_live?
      assert e.has_rhn_live?
      assert e.supports_cdn?
      assert e.has_cdn?
    end
  end

  test 'errors include errata and target' do
    post_json "#{API}?filter[release_name]=ASYNC&filter[errata_status]=REL_PREP",
              {'target' => 'rhn_stage', 'options' => ['bogus-option']}
    # This testdata should show that the error message includes the errata and
    # the target, so the caller knows which of the errata/targets triggered the
    # error
    assert_push_response_equal('push_bad_options')
  end

  test 'unexpected errors are propagated' do
    # Normally there's no known cases where creating a push job should raise
    # anything other than a validation error or DetailedArgumentError, but we
    # need code to deal with it just in case, so this test mocks such a
    # scenario.
    RhnStagePushJob.any_instance.expects(:validate_can_push?).at_least_once.
      raises(RuntimeError.new('simulated error'))

    assert_no_difference('PushJob.count') do
      post "#{API}?filter[release_name]=ASYNC&filter[errata_status]=REL_PREP&defaults=stage"
      assert_push_response_equal('push_simulated_error')
    end
  end

  # For testdata comparison, filters out / rewrites parts of a push job which
  # are unpredictable (ID, URL)
  def filter_push_jobs(push_jobs)
    # On success, we expect an array.
    # Other types would generally mean errors were encountered, so ignore it.
    unless push_jobs.is_a?(Array)
      return push_jobs
    end

    push_jobs.map do |pj|
      id = pj['id']
      url = pj['url']
      pj.merge('id' => id.nil? ? nil : "<some #{id.class}>",
               'url' => url.try(:sub, /\d+$/, '{some-id}'))
    end
  end

  def assert_push_response_equal(filename)
    actual = formatted_json_response :transform => self.method(:filter_push_jobs)
    assert_testdata_equal "#{API}/#{filename}.json", actual
  end

  test 'modify default tasks and options' do
    batch = Batch.find(4)
    assert batch.errata.empty?

    Errata.with_scope(:find => {:conditions => ['errata_main.id <= ?', MAX_ERRATA]}) do
      batch.release.errata.rel_prep.each do |e|
        e.batch = batch
        e.save!
      end

      assert_difference('PushJob.count', 3) do
        assert_difference('RhnStagePushJob.count', 3) do
          post_json "#{API}?filter[batch_id]=4", {
            'target' => 'rhn_stage',
            'exclude_options' => ['push_files'],
            'exclude_post_tasks' => ['reschedule_rhnqa']
          }
          assert_push_response_equal('push_modify_tasks_options_test')
        end
      end
    end
  end

end
