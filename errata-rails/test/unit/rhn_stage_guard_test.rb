require 'test_helper'

class RhnStageGuardTest < ActiveSupport::TestCase

  setup do
    qr = StateTransition.find_by_from_and_to('QE', 'REL_PREP')
    @guard = RhnStageGuard.new(:state_machine_rule_set => StateMachineRuleSet.last,
                               :state_transition => qr)
  end

  def rhn_stage_errata_mock
    errata = mock('Errata without RHN Stage support')
    errata.expects(:supports_rhn_stage?).returns(false)
    errata
  end

  test "returns default ok_message if errata is nil" do
    assert_match %r{on RHN Stage}, @guard.ok_message
  end

  test "rhn stage not support reflected in ok message" do
    assert_match %r{not used}, @guard.ok_message(rhn_stage_errata_mock)
  end

  test "defaults to ok if rhn is not supported" do
    assert @guard.transition_ok?(rhn_stage_errata_mock)
  end

  test "transition reflects state of rhnqa attribute" do
    # guard to avoid that it returns the default
    assert rhba_async.supports_rhn_stage?

    assert_equal rhba_async.rhnqa?, @guard.transition_ok?(rhba_async)
  end
end
