require 'test_helper'

class JobTrackerTest < ActiveSupport::TestCase
  test 'basic functionality' do
    nvrs = ["sblim-cim-client2-2.1.3-2.el6",
            "tomcat6-6.0.24-33.el6",
            "tomcat6-6.0.24-30.el6",
            "xorg-x11-drv-qxl-0.0.12-2.el5",
            "kdenetwork-3.5.4-10.el5_6.1"]
    product_version = ProductVersion.find_by_name "RHEL-6"
    update = ReleasedPackageUpdate.create!(:reason => 'testing', :user_input => {})
    t = JobTracker.track_jobs("#{product_version.name} Released Package Load",
                              "Adding/updating #{nvrs.length} released packages") do
      nvrs.each do |nvr|
        ReleasedPackage.send_later(
          :make_released_packages_for_build,
          nvr, product_version, update
        )
      end
    end

    assert t.has_unfinished_jobs?, "Tracker should have unfinished jobs"
    assert_equal 5, t.delayed_jobs.count
    assert_equal 5, t.total_job_count

    j = t.delayed_jobs.last
    j.reschedule('die')
    assert_equal 5, t.delayed_jobs.count
    assert_equal 4, t.delayed_jobs.untried.count
    assert_equal 1, t.delayed_jobs.failing.count
    assert_equal 'RUNNING', t.state
    assert_equal 5, t.total_job_count

    j = t.delayed_jobs.first
    j.reschedule('die')
    assert_equal 5, t.delayed_jobs.count
    assert_equal 3, t.delayed_jobs.untried.count
    assert_equal 2, t.delayed_jobs.failing.count
    assert_equal 'RUNNING', t.state

    t.delayed_jobs.untried.each {|dj| dj.finish}
    t = JobTracker.find t.id
    assert_equal 2, t.delayed_jobs.count
    assert_equal 0, t.delayed_jobs.untried.count
    assert_equal 2, t.delayed_jobs.failing.count
    assert_equal 'STALLED', t.state

    j = t.delayed_jobs.last
    j.finish
    t = JobTracker.find t.id
    assert_equal 1, t.delayed_jobs.count
    assert_equal 0, t.delayed_jobs.untried.count
    assert_equal 1, t.delayed_jobs.failing.count
    assert_equal 'STALLED', t.state

    j = t.delayed_jobs.last
    j.finish
    t = JobTracker.find t.id
    assert_equal 0, t.delayed_jobs.count
    assert_equal 0, t.delayed_jobs.untried.count
    assert_equal 0, t.delayed_jobs.failing.count
    assert_equal 5, t.total_job_count
    assert_equal 'FINISHED', t.state
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Job Completed: #{t.name}", mail.subject
  end

  test 'FAILED after max_attempts' do
    my_obj = "some dummy object"
    t = JobTracker.track_jobs('some failing jobs', 'test', :max_attempts => 4) do
      my_obj.send_later(:to_s)
      my_obj.send_later(:to_s, :will_fail_due_to_invalid_arg)
    end

    assert_equal 'RUNNING', t.state
    assert_equal 2, t.jobs.count

    run_jobs(t)

    (1..3).each do |i|
      # successful job should be gone
      assert_equal 1, t.jobs.count
      refute t.jobs.first.failed?
      assert_equal 'RUNNING', t.state
      Time.stubs(:now => (Time.now + 10.minutes + (i**4).minutes))
      run_jobs(t)
    end

    assert_equal 'FAILED', t.state
    # job should be set as failed
    assert_equal 1, t.jobs.count
    assert t.jobs.first.failed?

    # note the very last mail is the usual Delayed::Job exception mail
    mail = ActionMailer::Base.deliveries[-2]
    assert_equal "Job Failed: #{t.name}", mail.subject
  end

  test 'track_jobs returns nil when there are no jobs' do
    assert_no_difference('JobTracker.count') do
      tracker = JobTracker.track_jobs('null job', 'should not track anything') do
      end
      assert_nil tracker
    end
  end

  test 'send_mail toggles mail delivery' do
    [
      [{:send_mail => true}, 1],
      [{:send_mail => false}, 0],
      # default is to send
      [{}, 1],
    ].each do |opts,expected_mails|
      label = "case #{opts.inspect}, #{expected_mails}"
      tracker = JobTracker.track_jobs("test jobs", "some trivial jobs", opts) do
        "123".send_later(:to_i)
        "456".send_later(:to_i)
      end
      assert_equal 2, tracker.jobs.count, label

      assert_difference('ActionMailer::Base.deliveries.length', expected_mails, label) do
        run_jobs(tracker)
      end
    end
  end

  # Define a method that we'll use below with send_later to create a delayed job.
  # This job will raise if verification fails
  def self.verify_job_status
    jobs = JobTracker.last.jobs
    raise ArgumentError, "A job is expected but got #{jobs.size}" unless jobs.size == 1
    status = jobs.first.status
    raise ArgumentError, "'RUNNING' is expected but got '#{status}'" unless 'RUNNING' == status
  end

  test 'verify job/tracker state when rerunning a failed job' do
    job_tracker = JobTracker.track_jobs('test jobs', 'test', :max_attempts => 4) do
      JobTrackerTest.send_later(:verify_job_status)
    end

    job = job_tracker.jobs.first
    assert_equal 'QUEUED', job.status
    assert_equal 'RUNNING', job_tracker.state

    job.reschedule('die')
    job = job_tracker.jobs.first
    assert_equal 'FAILED', job.status
    assert_equal 'RUNNING', job_tracker.state

    Time.stubs(:now => (Time.now + 10.minutes))
    run_jobs(job_tracker)

    assert job_tracker.jobs.empty?
    assert_equal 'FINISHED', job_tracker.state
  end

  def run_jobs(tracker)
    tracker.jobs.each do |j|
      j.run_with_lock(1.minute, 'test worker')
    end
    tracker.reload
  end
end
