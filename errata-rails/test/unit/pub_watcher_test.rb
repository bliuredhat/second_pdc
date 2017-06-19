require 'test_helper'
require 'thread'
require 'timeout'

class PubWatcherTest < ActiveSupport::TestCase
  test 'pub watcher updates jobs as expected' do
    # use some arbitrary push jobs for this test and ignore all others.
    PushJob.where(:status => 'WAITING_ON_PUB').delete_all

    ids = [35511, 34511, 34509]
    jobs = PushJob.where(:id => ids).order('id desc')
    jobs.update_all(:status => 'WAITING_ON_PUB')

    (incomplete_job, failed_job, complete_job) = jobs.to_a

    pub_tasks = jobs.map(&:pub_task_id)
    # Mock the pub client to manipulate results
    # let one job fail, one succeed, one is still running
    pub_results = [
      {'id' => incomplete_job.pub_task_id, 'is_finished' => false},
      {'id' => failed_job.pub_task_id, 'is_finished' => true, 'is_failed' => true},
      {'id' => complete_job.pub_task_id, 'is_finished' => true},
    ]
    assert_difference('Delayed::Job.count', 1) do
      mock_pub_client(pub_tasks, pub_results)
    end
    dj = Delayed::Job.last

    # This job's status should be unmodified
    assert_equal 'WAITING_ON_PUB', incomplete_job.reload.status

    # This job should have been marked as failed
    assert_equal 'FAILED', failed_job.reload.status
    assert failed_job.log.ends_with?('Pub task failed'), failed_job.log

    # This job should be marked as about to process tasks, but the
    # tasks aren't actually processed until delayed job runs.
    assert_equal 'POST_PUSH_PROCESSING', complete_job.reload.status
    assert_match /Running post push tasks in background job #{dj.id}\b/, complete_job.log

    # The delayed job finishes up this push job.
    dj.invoke_job

    assert_equal 'COMPLETE', complete_job.reload.status
    assert complete_job.log.ends_with?('Post push tasks complete'), complete_job.log
  end

  def mock_pub_client(pub_tasks, results)
    match_params = lambda do |pub_tasks|
      args = Array.wrap(pub_tasks).map{|task| includes(task)}
      all_of(*args)
    end

    pc = mock()
    pc.expects(:get_tasks).with(match_params.call(pub_tasks)).returns(results)
    Push::PubClient.stubs(:get_connection => pc)
    Push::PubWatcher.new.perform
  end

  def mock_push_job_tasks(push_job_tasks_map)
    push_job_tasks_map.each_pair do |klass, tasks|
      tasks.each do |task, should_run|
        exp = klass.any_instance.expects("task_#{task}")
        should_run ? exp.once : exp.never
      end
    end
  end

  test "rhn and cdn finished at the same time" do
    errata = Errata.find(10836)
    # Test with clean
    errata.push_jobs.delete_all
    Delayed::Job.delete_all

    mock_errata_product_listing(errata)

    jobs = [RhnLivePushJob, CdnPushJob].map{|klass| create_push_job(errata, klass)}

    # Mock the pub client to manipulate results
    pub_tasks = jobs.map(&:pub_task_id)
    pub_results = [
      {'id' => pub_tasks[0], 'is_finished' => true},
      {'id' => pub_tasks[1], 'is_finished' => true},
    ]
    assert_difference('Delayed::Job.count', jobs.size) do
      mock_pub_client(pub_tasks, pub_results)
    end

    # Expected tasks
    # Note: the run_task method catches 'Exception' which
    # is too general. The error raised by mock will be caught
    # and it doesn't re-raise the error for optional tasks.
    push_job_tasks_map = {
      RhnLivePushJob => [
        [:check_error,         true],
        [:update_push_count,   false],
        [:mark_errata_shipped, false],
        [:update_bugzilla,     false],
        [:move_pushed_errata,  false],
        [:update_jira,         false],
      ],
      CdnPushJob => [
        [:check_error,         true],
        [:update_push_count,   true],
        [:mark_errata_shipped, true],
        [:update_bugzilla,     true],
        [:move_pushed_errata,  true],
        [:update_jira,         true],
      ],
    }
    mock_push_job_tasks(push_job_tasks_map)
    Delayed::Job.last(2).each(&:invoke_job)
  end

  test "rhn finished and cdn is still running" do
    errata = Errata.find(10836)
    # Test with clean
    errata.push_jobs.delete_all
    Delayed::Job.delete_all

    mock_errata_product_listing(errata)

    jobs = [RhnLivePushJob, CdnPushJob].map{|klass| create_push_job(errata, klass)}

    # Mock the pub client to manipulate results
    pub_tasks = jobs.map(&:pub_task_id)
    pub_results = [
      {'id' => pub_tasks[0], 'is_finished' => true},
      {'id' => pub_tasks[1], 'is_finished' => false},
    ]
    assert_difference('Delayed::Job.count', 1) do
      mock_pub_client(pub_tasks, pub_results)
    end

    # Expected tasks
    push_job_tasks_map = {
      RhnLivePushJob => [
        [:check_error,         true],
        [:update_push_count,   false],
        [:mark_errata_shipped, false],
        [:update_bugzilla,     false],
        [:move_pushed_errata,  false],
        [:update_jira,         false],
      ],
    }
    mock_push_job_tasks(push_job_tasks_map)
    Delayed::Job.last.invoke_job
  end

  test "cdn finished after rhn" do
    errata = Errata.find(10836)
    # Test with clean
    errata.push_jobs.delete_all
    Delayed::Job.delete_all

    mock_errata_product_listing(errata)

    (rhn_job, cdn_job) = [RhnLivePushJob, CdnPushJob].map{|klass| create_push_job(errata, klass)}

    # Set rhn push job to finish
    rhn_job.status = "COMPLETE"
    rhn_job.save!

    # Mock the pub client to manipulate results
    pub_results = [ {'id' => cdn_job.pub_task_id, 'is_finished' => true}, ]
    assert_difference('Delayed::Job.count', 1) do
      mock_pub_client(cdn_job.pub_task_id, pub_results)
    end

    # Expected tasks
    push_job_tasks_map = {
      CdnPushJob => [
        [:check_error,         true],
        [:update_push_count,   true],
        [:mark_errata_shipped, true],
        [:update_bugzilla,     true],
        [:move_pushed_errata,  true],
        [:update_jira,         true],
      ],
    }
    mock_push_job_tasks(push_job_tasks_map)
    Delayed::Job.last.invoke_job
  end

  test "rhn push job only" do
    errata = Errata.find(11110)
    # Test with clean
    errata.push_jobs.delete_all
    Delayed::Job.delete_all

    mock_errata_product_listing(errata)
    job = create_push_job(errata, RhnLivePushJob)

    # Mock the pub client to manipulate results
    pub_task = job.pub_task_id
    pub_results = [
      {'id' => pub_task, 'is_finished' => true},
    ]
    assert_difference('Delayed::Job.count', 1) do
      mock_pub_client(pub_task, pub_results)
    end

    # Expected tasks
    push_job_tasks_map = {
      RhnLivePushJob => [
        [:check_error,           true],
        [:update_push_count,     true],
        [:mark_errata_shipped,   true],
        [:update_bugzilla,       true],
        [:move_pushed_errata,    true],
        [:update_jira,           true],
        [:push_xml_to_secalert,  true],
        [:request_translation,   true],
        [:push_oval_to_secalert, true],
      ],
      CdnPushJob => [
        [:check_error,           false],
        [:update_push_count,     false],
        [:mark_errata_shipped,   false],
        [:update_bugzilla,       false],
        [:move_pushed_errata,    false],
        [:update_jira,           false],
        [:push_xml_to_secalert,  false],
        [:request_translation,   false],
        [:push_oval_to_secalert, false],
      ],
    }
    mock_push_job_tasks(push_job_tasks_map)
    Delayed::Job.last.invoke_job
  end

  test "Don't create delayed job if no post push tasks to run" do
    errata = Errata.find(11110)
    # Test with clean
    errata.push_jobs.delete_all

    mock_errata_product_listing(errata)
    job = create_push_job(errata, RhnLivePushJob)
    # Mock all tasks unavailable
    RhnLivePushJob.any_instance.stubs(:task_availability => NotAvailable.new('testing'))

    # Mock the pub client to manipulate results
    pub_task = job.pub_task_id
    pub_results = [{'id' => pub_task, 'is_finished' => true}]
    assert_no_difference('Delayed::Job.count') do
      mock_pub_client(pub_task, pub_results)
    end
    assert_equal "COMPLETE", job.reload.status, "Job status not set to 'COMPLETE'"
  end

  test "can be safely invoked from multiple threads" do
    # This test can't use the test framework's usual transaction wrapping, due
    # to using multiple threads (transactions are thread-local).
    # For this reason, we avoid calling helper methods which implicitly create
    # records (such as releng_user etc.) and we need to explicitly clean up
    # anything that we do create.
    THREAD_COUNT = 4
    PUB_TASK_ID = 888899
    TIMEOUT = 20

    # Arbitrarily selected user capable of doing a push.
    user = User.find(275188)

    # Push job used as a basis for this test.  This will be cloned.  The details
    # aren't important, we just want enough to be able to create a new, valid
    # job.
    src_push_job = PushJob.find(39575)

    main_producer = Queue.new
    main_consumer = Queue.new

    # Fake all pub tasks as failing
    Push::PubClient.expects(:get_connection).times(THREAD_COUNT).returns(pub_client_all_tasks_failed)

    # Exactly one thread should mark job as failed.  We piggy-back on
    # task_check_error because mocking mark_as_failed! would prevent the job
    # from being saved, making the test invalid.
    RhnLivePushJob.any_instance.expects(:task_check_error).once

    # No threads should mark job as successful.
    RhnLivePushJob.any_instance.expects(:pub_success!).never

    # Synchronize job lookup to give the worst possible case:
    # all threads load their own copy of the job at the same time.
    test = self
    synchronized_for_pub_task = lambda do |pub_task_id|
      test.assert_equal PUB_TASK_ID, pub_task_id
      # to_a to force load of matching push jobs now
      out = PushJob.where(:pub_task_id => pub_task_id).tap(&:to_a)
      main_consumer.push(nil)
      main_producer.pop
      out
    end

    src_attr = src_push_job.attributes.slice(
      *%w[push_target_id post_push_tasks errata_id])

    pj = RhnLivePushJob.create!(src_attr.merge(
                                 :pushed_by => user,
                                 :status => 'WAITING_ON_PUB',
                                 :pub_task_id => PUB_TASK_ID))

    begin
      # Prevent fail by hanging
      Timeout.timeout(TIMEOUT) do
        self.class.with_replaced_method(PushJob, :for_pub_task, synchronized_for_pub_task) do
          # Start pub watcher performs, in parallel
          threads = (1..THREAD_COUNT).map do
            Thread.new{ Push::PubWatcher.perform }
          end

          # Wait until all threads have loaded job...
          threads.each{|_| main_consumer.pop }
          # ...then let all threads proceed to return job
          threads.each{|_| main_producer.push(nil) }

          # Now let threads complete.  (If unexpected methods are called on the
          # jobs, this will raise, failing the test.)
          threads.each(&:join)
        end
      end
    ensure
      pj.delete
    end
  end

  # Returns a dummy pub client which returns every queried pub task ID as
  # finished and failed.
  def pub_client_all_tasks_failed
    client = Push::DummyClient.new
    client.singleton_class.send(:define_method, :get_tasks) do |ids|
      ids.map{|id| {'id' => id, 'is_finished' => true, 'is_failed' => true}}
    end
    client
  end

  # Disable the usual wrapping in transaction for this test.
  # See commentary in the test.
  uses_transaction 'test_can_be_safely_invoked_from_multiple_threads'
end
