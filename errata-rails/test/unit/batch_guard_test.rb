require 'test_helper'

class BatchGuardTest < ActiveSupport::TestCase

  def batch_guard
    qr = StateTransition.find_by_from_and_to('REL_PREP', 'PUSH_READY')
    BatchGuard.new(:state_machine_rule_set => StateMachineRuleSet.last,
                   :state_transition => qr)
  end

  def mock_batch
    batch = mock
    batch.stubs(:future_release_date?).returns(false)
    batch.stubs(:release_date).returns(Time.now + 1.day)
    batch.stubs(:blockers).returns(Errata.where('0 = 1'))
    batch.stubs(:is_active?).returns(true)
    batch
  end

  def mock_errata(batch = nil)
    errata = mock
    errata.stubs(:batch).returns(batch)
    errata.stubs(:is_security?).returns(false)
    errata.stubs(:is_batch_blocker?).returns(false)
    errata
  end

  test "returns default ok_message if errata is nil" do
    assert_equal 'Batch checks complete', batch_guard.ok_message
  end

  test "advisory not part of a batch" do
    errata = mock_errata
    guard = batch_guard

    assert guard.transition_ok?(errata)
    assert_equal 'Advisory is not part of a batch', guard.failure_message(errata)
  end

  test "future release dated batch blocks" do
    batch = mock_batch
    batch.stubs(:future_release_date?).returns(true)
    errata = mock_errata(batch)
    guard = batch_guard

    refute guard.transition_ok?(errata)
    assert_equal 'Batch release date is in the future', guard.failure_message(errata)
  end

  test "batch has no release date set" do
    batch = mock_batch
    batch.stubs(:release_date).returns(nil)
    errata = mock_errata(batch)
    guard = batch_guard

    refute guard.transition_ok?(errata)
    assert_equal 'Batch has no release date', guard.failure_message(errata)
  end

  test "errata blocked by batch blocker" do
    batch = mock_batch
    batch.stubs(:blockers).returns([Errata.first])
    errata = mock_errata(batch)
    guard = batch_guard

    refute guard.transition_ok?(errata)
    assert_match %r{Batch is blocked}, guard.failure_message(errata)
  end

  test "multiple batch failure messages" do
    batch = mock_batch
    batch.stubs(:release_date).returns(nil)
    batch.stubs(:blockers).returns([Errata.first])
    errata = mock_errata(batch)
    guard = batch_guard

    refute guard.transition_ok?(errata)
    failure_message = guard.failure_message(errata)

    assert_match %r{Batch has no release date}, failure_message
    assert_match %r{Batch is blocked}, failure_message
  end

  test "batch blocking errata may transition" do
    batch = mock_batch
    batch.stubs(:blockers).returns([Errata.first])
    errata = mock_errata(batch)
    errata.stubs(:is_batch_blocker?).returns(true)
    guard = batch_guard

    assert guard.transition_ok?(errata)
    assert_match %r{Batch is blocked}, guard.failure_message(errata)
  end

end
