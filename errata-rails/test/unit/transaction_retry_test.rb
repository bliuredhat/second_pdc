require 'test_helper'

class TransactionRetryTest < ActiveSupport::TestCase
  test 'transaction fails on deadlock' do
    spy = []

    # This is a baseline test:
    # Using the default activerecord behavior, a fatal error will occur here
    error = assert_raises(ActiveRecord::StatementInvalid) do
      safe_thread_join deadlocking_threads(:transaction, spy)
    end
    assert_match /Deadlock found/, error.message

    # Both threads should have started but only one of the threads will have
    # completed.
    assert_equal 3, spy.length
    assert_equal [:started_a, :started_b], spy[0..1].sort_by(&:to_s)
    assert [:finished_a, :finished_b].include?(spy[2])
  end

  test 'transaction_with_retry recovers on deadlock' do
    spy = []

    logs = capture_logs do
      safe_thread_join deadlocking_threads(:transaction_with_retry, spy)
    end

    # Both threads should have started, then one of them completed,
    # then the other restarted and finally completed.
    assert_equal 5, spy.length
    assert_equal [:started_a, :started_b], spy.shift(2).sort_by(&:to_s)
    first_finished = spy.shift
    assert [:finished_a, :finished_b].include?(first_finished)

    if first_finished == :finished_a
      assert_equal [:started_b, :finished_b], spy
    else
      assert_equal [:started_a, :finished_a], spy
    end

    messages = logs.map{ |l| l[:msg] }
    assert_equal 1, messages.grep(%r{^\[1/5\] retrying transaction:.*Deadlock.*COUNT}).length
  end

  test 'transaction_with_retry gives up on repeated deadlock' do
    logs = capture_logs do
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction_with_retry do
          # Simulating the deadlock here because I couldn't come up with a way
          # to get a single thread to reliably deadlock N times...
          raise ActiveRecord::StatementInvalid,
                'Mysql2::Error: Deadlock found when trying to get lock; try restarting transaction: quux'
        end
      end
    end

    messages = logs.map{ |l| l[:msg] }
    assert_equal 1, messages.grep(%r{^\[4/5\] retrying transaction:.*Deadlock.*quux}).length
    assert_equal 1, messages.grep(%r{^\[5/5\] abandoning transaction:.*Deadlock.*quux}).length
  end

  # Returns two threads designed to deadlock, each one wrapped by the specified
  # transaction method.
  #
  # The threads will stream started/finished events into +spy+ so the caller can
  # determine the sequence of events.
  def deadlocking_threads(transaction_method, spy = [])
    locked_a = false
    locked_b = false

    lock_a_then_b = lambda do
      spy << :started_a
      Errata.lock.count
      locked_a = true
      Thread.pass until locked_b
      Bug.lock.count
      spy << :finished_a
    end

    lock_b_then_a = lambda do
      spy << :started_b
      Bug.lock.count
      locked_b = true
      Thread.pass until locked_a
      Errata.lock.count
      spy << :finished_b
    end

    [lock_a_then_b, lock_b_then_a].map do |block|
      Thread.new do
        ActiveRecord::Base.send(transaction_method, &block)
      end
    end
  end

  # Like threads.each(&:join), however it guarantees that _all_ threads are
  # joined, even if some of them raise errors on join.
  #
  # An exception during join is propagated.  If multiple threads raise on join,
  # it's undefined which one of the errors is propagated.
  def safe_thread_join(threads)
    error = nil

    threads.each do |t|
      begin
        t.join
      rescue Exception => thread_error
        error = thread_error
      end
    end

    raise error if error
  end
end
