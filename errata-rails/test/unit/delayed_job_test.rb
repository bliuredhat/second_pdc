require 'test_helper'

class DelayedJobTest < ActiveSupport::TestCase

  setup do
    # This test needs to start with a clean slate
    Delayed::Job.delete_all
  end

  # precondition, other tests don't make sense without this
  test 'no delayed jobs by default' do
    assert_equal 0, Delayed::Job.count, 'delayed jobs unexpectedly exist in the test database'
  end

  test 'enqueue_once handles priority and run_at parameters correctly' do
    assert_difference('Delayed::Job.count') do
      run_at = 12.minutes.from_now
      job = Delayed::Job.enqueue_once SomeJob.new(123), 10, run_at
      assert_equal 10, job.priority
      assert_equal run_at.to_i, job.run_at.to_i
    end
  end

  test 'enqueue_once enqueues two different jobs OK' do
    assert_difference('Delayed::Job.count', 2) do
      job1 = Delayed::Job.enqueue_once SomeJob.new(123)
      job2 = Delayed::Job.enqueue_once SomeJob.new(234)
      assert_not_nil job1
      assert_not_nil job2
    end
  end

  test "enqueue_once won't enqueue the same job" do
    assert_difference('Delayed::Job.count') do
      job1 = Delayed::Job.enqueue_once SomeJob.new(123)
      job2 = Delayed::Job.enqueue_once SomeJob.new(123)
      assert_not_nil job1
      assert_nil job2
    end
  end

  test "enqueue_once won't enqueue the same job even if priority and run_at are provided" do
    assert_difference('Delayed::Job.count') do
      job1 = Delayed::Job.enqueue_once SomeJob.new(123)
      job2 = Delayed::Job.enqueue_once SomeJob.new(123), 7, 12.minutes.from_now
      assert_not_nil job1
      assert_nil job2
    end
  end

  test "enqueue_once won't enqueue the same invokable method" do
    assert_difference('Delayed::Job.count') do
      job1 = SomeJob.new(1).enqueue_once(:sum_and_save, 41)
      job2 = SomeJob.new(1).enqueue_once(:sum_and_save, 41)
      assert_not_nil job1
      assert_nil job2
    end
  end

  test "enqueue_once will enqueue invokable method with different callee state" do
    assert_difference('Delayed::Job.count', 2) do
      job1 = SomeJob.new(1).enqueue_once(:sum_and_save, 41)
      job2 = SomeJob.new(2).enqueue_once(:sum_and_save, 41)
      assert_not_nil job1
      assert_not_nil job2
    end
  end

  test "enqueue_once will enqueue invokable method with different arguments" do
    assert_difference('Delayed::Job.count', 2) do
      job1 = SomeJob.new(1).enqueue_once(:sum_and_save, 41)
      job2 = SomeJob.new(1).enqueue_once(:sum_and_save, 42)
      assert_not_nil job1
      assert_not_nil job2
    end
  end

  test "enqueue_once won't enqueue the same invokable class method" do
    assert_difference('Delayed::Job.count') do
      job1 = SomeJob.enqueue_once(:class_method, 1)
      job2 = SomeJob.enqueue_once(:class_method, 1)
      assert_not_nil job1
      assert_nil job2
    end
  end

  test "enqueue_once will enqueue invokable class method with different arguments" do
    assert_difference('Delayed::Job.count', 2) do
      job1 = SomeJob.enqueue_once(:class_method, 1)
      job2 = SomeJob.enqueue_once(:class_method, 2)
      assert_not_nil job1
      assert_not_nil job2
    end
  end

  test "invoking jobs works normally" do
    2.times do
      Delayed::Job.enqueue_once SomeJob.new(123), 10, 10.minutes.from_now
      Delayed::Job.enqueue_once SomeJob.new(234)
      SomeJob.new(1).enqueue_once :sum_and_save, 41
      SomeJob.new(1).enqueue_once :sum_and_save, 50
      SomeJob.new(2).enqueue_once :sum_and_save, 41
      SomeJob.enqueue_once :class_method, 88
      SomeJob.enqueue_once :class_method, 89
    end

    assert_equal 7, Delayed::Job.count
    run_all_delayed_jobs
    assert_equal 0, Delayed::Job.count

    # now make sure everything really was invoked.
    # Note we don't test the order, since run_at is per-second granularity only
    assert_equal [123, 234], SomeJob.invoked_job.sort
    assert_equal [42, 51, 43].sort, SomeJob.invoked_method.sort
    assert_equal [88, 89], SomeJob.invoked_class_method.sort
  end

  test "reset attempts if no error" do
    count = 5
    SomeJob.any_instance.expects(:perform).times(count).raises(StandardError, "Failed intentionally")
    SomeJob.any_instance.stubs(:rerun?).returns(true)
    job = Delayed::Job.enqueue SomeJob.new(123), 1, 10.minutes.from_now
    # Will fail 5 times here
    count.times do
      run_all_delayed_jobs
    end

    job.reload
    assert_equal count, job.attempts

    # Attempts should reset to 0 if no error occur
    SomeJob.any_instance.expects(:perform).once.returns(true)
    run_all_delayed_jobs
    job.reload
    assert_equal 0, job.attempts
  end

  class SomeJob
    # these keep track of what was invoked
    def self.invoked_job
      @@invoked_job ||= []
    end

    def self.invoked_method
      @@invoked_method ||= []
    end

    def self.invoked_class_method
      @@invoked_class_method ||= []
    end

    def initialize(x)
      @x = x
    end

    def perform
      SomeJob.invoked_job << @x
    end

    # intended to be invoked as a performable method.
    def sum_and_save(val)
      SomeJob.invoked_method << (@x + val)
    end

    def self.class_method(val)
      SomeJob.invoked_class_method << val
    end

    def rerun?
      false
    end
  end
end
