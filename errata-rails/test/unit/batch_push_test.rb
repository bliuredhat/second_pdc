require 'test_helper'

class BatchPushTest  < ActiveSupport::TestCase

  setup do
    MockLogger.reset
    Rails.stubs(:logger => MockLogger)
  end

  def get_errata
    e = Errata.find(19029)
    e.update_attributes(:batch_id => 4)
    e
  end

  test "all errata shipped causes batch to be marked as released" do
    e = get_errata

    # Should only be one erratum in this batch
    assert_equal 1, e.batch.errata.count, 'Unexpected errata in batch'

    e.change_state!(State::IN_PUSH, releng_user)

    # The batch should not have released_at timestamp
    assert e.batch.released_at.nil?

    e.change_state!(State::SHIPPED_LIVE, releng_user)

    assert_match %r{Marking batch '.*' as released}, MockLogger.log.last

    # The batch should have a released_at timestamp
    refute e.batch.reload.released_at.nil?
  end

  test "pre-release errata in batch" do
    e = get_errata

    # This erratum is in QE state
    qe_erratum = Errata.find(19031)
    assert qe_erratum.status_is?(State::QE)

    # This erratum is in REL_PREP state
    rel_prep_erratum = Errata.find(19463)
    assert rel_prep_erratum.status_is?(State::REL_PREP)

    # Set batch on QE advisory
    qe_erratum.update_attributes(:batch_id => 4)
    assert_match %r{Advisory batch has been set to '.*'}, qe_erratum.comments.last.text

    # Set batch on REL_PREP advisory
    rel_prep_erratum.update_attributes(:batch_id => 4)
    assert_match %r{Advisory batch has been set to '.*'}, rel_prep_erratum.comments.last.text

    # Set batch blocker
    qe_erratum.update_attributes(:is_batch_blocker => true)
    assert_match %r{Advisory is set to be a batch blocker}, qe_erratum.comments.last.text

    # Should be 3 errata in this batch
    assert_equal 3, e.batch.errata.count, 'Unexpected errata in batch'

    e.change_state!(State::IN_PUSH, releng_user)

    # Should now only be 2 errata in this batch
    assert_equal 2, e.batch.errata.count, 'Unexpected errata in batch'

    # The rel_prep_erratum will still be in the batch
    assert_equal 4, rel_prep_erratum.reload.batch_id

    # The qe_erratum will be bumped to another batch
    assert_match %r{Moving errata '.*' \(QE\) to batch '.*'}, MockLogger.log.last
    assert_not_equal 4, qe_erratum.reload.batch_id

    # Check comments have been added to advisory
    assert_match %r{Advisory batch changed from 'batch_00004' to '#{qe_erratum.batch.name}'}, qe_erratum.comments[-2].text
    assert_match %r{Advisory moved from shipping batch 'batch_00004' because it has status 'QE'}, qe_erratum.comments.last.text
  end

  test "other errata released in batch" do
    e = get_errata

    # This erratum is in PUSH_READY state
    push_ready_erratum = Errata.find(19030)
    assert push_ready_erratum.status_is?(State::PUSH_READY)
    push_ready_erratum.update_attributes(:batch_id => 4)

    # Should only be 2 errata in this batch
    assert_equal 2, e.batch.errata.count, 'Unexpected errata in batch'

    e.change_state!(State::IN_PUSH, releng_user)

    # The batch should not have released_at timestamp
    assert e.batch.released_at.nil?

    e.change_state!(State::SHIPPED_LIVE, releng_user)

    # Logs are updated
    assert_match %r{Batch '.*' still has errata to be shipped}, MockLogger.log.last

    # The batch should not have released_at timestamp
    assert e.batch.reload.released_at.nil?
  end

  test "all errata dropped does not cause batch to be marked as released" do
    e = get_errata

    # Should only be one erratum in this batch
    assert_equal 1, e.batch.errata.count, 'Unexpected errata in batch'

    e.change_state!(State::DROPPED_NO_SHIP, admin_user)

    assert MockLogger.log.empty?, 'Unexpected message logged'

    # The batch should have no released_at timestamp
    assert e.batch.reload.released_at.nil?
  end

  test "last erratum dropped if any shipped causes batch to be marked as released" do
    e = get_errata

    # Add another erratum to batch and ship it
    e2 = Errata.find(19030)
    assert e2.status_is?(State::PUSH_READY)
    e2.update_attributes(:batch_id => 4)
    e2.change_state!(State::IN_PUSH, releng_user)
    e2.change_state!(State::SHIPPED_LIVE, releng_user)

    # Should only be 2 errata in this batch
    assert_equal 2, e.batch.errata.count, 'Unexpected errata in batch'

    # Drop the last erratum in batch
    e.change_state!(State::DROPPED_NO_SHIP, admin_user)

    assert_match %r{Marking batch '.*' as released}, MockLogger.log.last

    # The batch should have a released_at timestamp
    refute e.batch.reload.released_at.nil?
  end
end
