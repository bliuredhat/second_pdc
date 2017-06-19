require 'test_helper'

class DelayedJobMessagingTest < ActiveSupport::TestCase

  setup do
    # This test needs to start with a clean slate
    Delayed::Job.delete_all
    SomeJob.reset
  end

  # precondition, other tests don't make sense without this
  test 'starts with no delayed jobs' do
    assert_equal 0, Delayed::Job.count, 'delayed jobs unexpectedly exist in the test database'
  end

  test 'jobs are executed based on priority' do
    shuffled = (-5..5).to_a.shuffle
    # Max to min is the prioritized list of jobs [n ., 0, .. -m]
    prioritized = shuffled.sort.reverse

    job = SomeJob.new
    shuffled.each { |priority| job.send_prioritized(priority, :run, priority) }
    run_all_delayed_jobs

    assert_equal prioritized, SomeJob.ran
  end

  class SomeJob
    # keep track of what ran
    cattr_accessor :ran
    @@ran = []

    def self.reset
      @@ran = []
    end

    def run(priority)
      @@ran << priority
    end
  end
end
