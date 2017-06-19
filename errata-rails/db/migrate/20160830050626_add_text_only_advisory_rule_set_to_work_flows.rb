class AddTextOnlyAdvisoryRuleSetToWorkFlows < ActiveRecord::Migration
  def up
    transition = StateTransition.find_by_from_and_to 'QE', 'REL_PREP'
    ActiveRecord::Base.transaction do
      # Every ruleset has this guard applied - 100% mandatory
      StateMachineRuleSet.all.each do |ruleset|
        TextOnlyAdvisoryGuard.create!(:state_machine_rule_set => ruleset,
                                      :guard_type => 'block',
                                      :state_transition => transition)
      end
    end
  end

  def down
    TextOnlyAdvisoryGuard.delete_all
  end
end
