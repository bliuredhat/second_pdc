class AddTextOnlyGuardToPushLive < ActiveRecord::Migration
  def up
    transition = StateTransition.find_by_from_and_to 'PUSH_READY', 'IN_PUSH'
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
    transition = StateTransition.find_by_from_and_to 'PUSH_READY', 'IN_PUSH'
    TextOnlyAdvisoryGuard.where(state_transition_id: transition).delete_all
  end
end
