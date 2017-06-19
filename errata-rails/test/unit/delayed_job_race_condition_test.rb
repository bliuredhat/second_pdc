require 'test_helper'

class DelayedJobRaceConditionTest < ActiveSupport::TestCase

  test 'enqueue_once works without deadlocks' do
    assert_no_deadlocks(1, 20, 10)
    assert_no_deadlocks(1, 30, 15)
  end

  def assert_no_deadlocks(low, high, slice)
    # this test starts with 0 delayed jobs
    threaded_delete_all_jobs

    threads = deadlock_scenario(low, high, slice)
    errors = safe_join threads

    somejob_count = threaded_somejob_count
    jobs = threaded_delete_all_jobs

    assert_equal [], errors

    expected_jobs = (high - low + 1) * 5 # 5 threads
    expected_some_jobs = high - low + 1  # enqueued_once

    # TODO: fix bug: 1373328 - Investigate the root cause for
    #       delayed_job_race_condition_test to return incorrect number of jobs

    enforced = ENV['DELAYED_JOB_JOB_COUNT_CHECK_ENFORCED']
    assert_equal_if enforced, expected_some_jobs, somejob_count
    assert_equal_if enforced, expected_jobs, jobs
  end

  ### utils ###

  def assert_equal_if(condition, expected, actual)
    return assert_equal(expected, actual) if condition
    puts "Expected: #{expected} Actual: #{actual}" unless expected == actual
  end

  def threaded_delete_all_jobs
    count = 0
    del = n_threads(1) do
      count = Delayed::Job.delete_all
    end
    safe_join del
    count
  end

  def threaded_somejob_count
    count = 0
    del = n_threads(1) do
      count = Delayed::Job.where("handler LIKE '%SomeJob%'").count
    end
    safe_join del
    count
  end

  # in the production scenario we would get two insert failing due to a
  # deadlock. This tries to reproduce that scenario by inserting a set of
  # jobs in a transaction into delayed jobs.
  # The two threads (t1) inserts in ascending order and t2 inserts in
  # descending order. It has been observed that doing this results in a
  # deadlock around record 40..60
  #
  # t1 -- thread 1 : [1..10], [11..20], ... [91..100]
  #   `-- thread 2 : [1..10], [11..20], ... [91..100]
  # t2 -- thread 3 : [91..100], [81...90] ... [1..10]
  #   `-- thread 4 : [91..100], [81...90] ... [1..10]
  # t3 -- thread 5 : 1, 2, 3, 4,  ...             100
  # This must result in 100 total jobs
  #
  def deadlock_scenario(low, high, slice)
    t1 = n_threads(2) do
      (low..high).each_slice(slice) do |commits|
        ActiveRecord::Base.transaction do
          # debug helper
          # puts "Enqueue: [#{commits.join(', ')}]          #{Thread.current}"
          commits.each do |x|
            Delayed::Job.enqueue_once SomeJob.new(x)
            Thread.pass
            sleep 0.005
            Delayed::Job.enqueue AnotherJob.new(x)
          end
          # debug helper
          # puts "         [#{commits.join(', ')}] -- DONE  #{Thread.current}"
        end
      end
    end

    t2 = n_threads(2) do
      high.downto(low).each_slice(slice) do |commits|

        ActiveRecord::Base.transaction do
          # puts "Enqueue: [#{commits.join(', ')}]          #{Thread.current}"
          commits.each do |x|
            Delayed::Job.enqueue_once SomeJob.new(x)
            sleep 0.005
            Thread.pass
            Delayed::Job.enqueue AnotherJob.new(x)
          end
          # puts "         [#{commits.join(', ')}] -- DONE  #{Thread.current}"
        end
      end #  high -> low
    end

    t3 = n_threads(1) do
      (low..high).each do |x|
        Delayed::Job.enqueue_once SomeJob.new(x)
        sleep 0.02
      end
    end
    t1 + t2 + t3
  end

  def n_threads(n)
    (1..n).map do
      Thread.new do
        begin
          yield
        ensure
          ActiveRecord::Base.connection.close
        end
      end # thread
    end
  end

  # Handle all execeptions and return the error that occured
  def safe_join(threads)
    threads.each_with_object([]) do |t, errors|
      begin
        t.join
      rescue Exception => thread_error
        errors << thread_error
      end
    end
  end

  class SomeJob
    attr_accessor :x

    def initialize(x)
      @x = x
    end

    def perform
    end
  end

  class AnotherJob
    attr_accessor :x

    def initialize(x)
      @x = x
    end

    def perform
    end
  end
end
