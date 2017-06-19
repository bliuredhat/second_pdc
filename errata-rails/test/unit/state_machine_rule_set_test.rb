require 'test_helper'

class StateMachineRuleSetTest < ActiveSupport::TestCase
  setup do
    @errata = Errata.find(18894)
  end

  test "get all the transition guards for current advisory state" do
    actual = @errata.state_machine_rule_set.guards_in_state(@errata.status).sort_by(&:id)
    expected = StateTransitionGuard.where(:id => [5,6,7,8,20,180,196]).sort_by(&:id)
    assert_equal expected, actual
  end

  test "get TPS transition guards in QE state" do
    assert_equal "QE", @errata.status, "Possible fixture error: Advisory #{@errata.id} is no longer in QE state."
    [
     [:tps_guards_in_current_state, TpsGuard.where(:id => 5)],
     [:tps_rhnqa_guards_in_current_state, TpsRhnqaGuard.where(:id => 6)]
    ].each do |method, expected|
      actual = @errata.send(method)
      assert_equal expected, actual
    end
  end

  test "creating a duplicate" do
    old_rs = StateMachineRuleSet.find(15)
    new_rs = old_rs.create_duplicate_rule_set!("foo", "bar")

    assert_not_equal old_rs, new_rs
    assert_equal ["foo", "bar"], [new_rs.name, new_rs.description]

    guard_to_s = lambda { |g| "#{g.type} #{g.guard_type} #{g.state_transition_id}" }
    assert_equal old_rs.state_transition_guards.map(&guard_to_s).sort, new_rs.state_transition_guards.map(&guard_to_s).sort

    # (Note: This would fail for some other StateMachineRuleSet records in fixtures data. See commit for explanation.)
    assert_equal old_rs.test_requirements, new_rs.test_requirements
  end
end
