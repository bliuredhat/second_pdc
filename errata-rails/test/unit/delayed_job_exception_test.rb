require 'test_helper'

class DelayedJobExceptionTest < ActiveSupport::TestCase
  # Notes:
  # - We have an old version of delayed_job.
  #   In newer versions have to use Delayed::Worker.new.work_off
  #   instead of Delayed::Job.work_off)
  # - For the notification email to be testable, we need to
  #   enable ExceptionNotification in test. (Hopefully that won't
  #   cause any unexpected weirdness).

  setup do
    Delayed::Job.delete_all
  end

 class DoesNothing
    def perform
    end
  end

  class GoesBoom
    def perform
      raise 'boom!'
    end
  end

  test "exception thrown via force_sync_delayed_jobs" do
    ex = assert_raises(RuntimeError) do
      force_sync_delayed_jobs do
        Delayed::Job.enqueue(GoesBoom.new)
      end
    end
    assert_equal 'boom!', ex.message
  end

  test "can enqueue and work off a noop job" do
    Delayed::Job.enqueue(DoesNothing.new)
    assert_equal 1, Delayed::Job.count
    Delayed::Job.work_off(1)
    assert_equal 0, Delayed::Job.count
  end

  test "exception thrown by delayed job sends notification email" do
    Delayed::Job.enqueue(GoesBoom.new)
    assert_equal 1, Delayed::Job.count
    assert_difference('ActionMailer::Base.deliveries.count', 1) do
      Delayed::Job.work_off(1)
    end
    assert_equal 1, Delayed::Job.count
    notification_email = ActionMailer::Base.deliveries.last
    assert_equal '[test Errata System Error]  (RuntimeError) "boom!"', notification_email.subject
    assert_match 'A RuntimeError occurred in background', notification_email.body.to_s
  end

end
