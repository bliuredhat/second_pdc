require 'test_helper'
require 'message_bus'

class MessageBusTest < ActiveSupport::TestCase

  setup do
    # Time class in ruby 2.2 has more precision (msec and nanosec) than in 1.8.
    # This precision is lost when saved to Settings (write to db) and fetched
    # back. Hence the following snippet fails in Ruby 2.2
    #   x  = Time.now
    #   Settings.foo = x
    #   assert x, Settings.foo
    # stub Time.now so that anything less than a second is set to 0
    Time.stubs(:now => Time.gm(2012, 12, 12, 12, 12, 12))
  end

  test "always reconcile if mbus is not used" do
    Settings.mbus_last_receive = nil
    last_ts = Time.now - 5.seconds
    got_ts = nil
    Settings.test_reconcile_timestamp = last_ts
    MessageBus.reconcile(:test_reconcile) {|ts, now| got_ts = ts}

    assert_equal last_ts, got_ts
    assert last_ts < Settings.test_reconcile_timestamp
  end

  test "reconcile if mbus not updated for a while" do
    Settings.mbus_last_receive = Time.now - 30.minutes
    last_ts = Time.now - 5.seconds
    got_ts = nil
    Settings.test_reconcile_timestamp = last_ts
    MessageBus.reconcile(:test_reconcile) {|ts, now| got_ts = ts}

    assert_equal last_ts, got_ts
    assert last_ts < Settings.test_reconcile_timestamp
  end

  test "reconcile if not reconciled for a while" do
    Settings.mbus_last_receive = Time.now - 1.minutes
    last_ts = Time.now - 20.hours
    got_ts = nil
    Settings.test_reconcile_timestamp = last_ts
    MessageBus.reconcile(:test_reconcile) {|ts, now| got_ts = ts}

    assert_equal last_ts, got_ts
    assert last_ts < Settings.test_reconcile_timestamp
  end

  test "reconcile if handler is disabled" do
    Settings.mbus_last_receive = Time.now - 1.minutes
    last_ts = Time.now - 2.hours
    got_ts = nil
    Settings.test_reconcile_timestamp = last_ts
    MessageBus.reconcile(:test_reconcile) {|ts, now| got_ts = ts}

    assert_equal last_ts, got_ts
    assert last_ts < Settings.test_reconcile_timestamp
  end

  test "don't reconcile by default if mbus is working" do
    Settings.mbus_last_receive = Time.now - 1.minutes
    last_ts = Time.now - 2.hours
    Settings.test_reconcile_timestamp = last_ts
    Settings.mbus_test_reconcile_enabled = true
    MessageBus.reconcile(:test_reconcile) {|*args| flunk('Should not have been invoked!')}

    assert_equal last_ts, Settings.test_reconcile_timestamp
  end

  test "don't update timestamp on crash" do
    Settings.mbus_last_receive = nil
    last_ts = Time.now - 5.seconds
    got_ts = nil
    got_error = nil
    Settings.test_reconcile_timestamp = last_ts
    begin
      MessageBus.reconcile(:test_reconcile) {|*args| 1/0}
    rescue ZeroDivisionError => e
      got_error = e
    end

    assert_equal last_ts, Settings.test_reconcile_timestamp
    assert_not_nil got_error
  end

end
