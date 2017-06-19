class AddTextOnlyGuardFromRelPrepToPushReady < ActiveRecord::Migration

  def up
    ActiveRecord::Base.transaction do
      transition = rp_transition
      # Every ruleset has this guard applied - 100% mandatory
      StateMachineRuleSet.all.each do |ruleset|
        TextOnlyAdvisoryGuard.create!(:state_machine_rule_set => ruleset,
                                      :guard_type => 'block',
                                      :state_transition => transition)
      end
    end
  end

  def down
    TextOnlyAdvisoryGuard.where(:state_transition_id => rp_transition).delete_all
  end

  def rp_transition
    StateTransition.find_by_from_and_to 'REL_PREP', 'PUSH_READY'
  end
end
