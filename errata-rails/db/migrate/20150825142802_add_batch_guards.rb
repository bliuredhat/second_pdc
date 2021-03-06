class AddBatchGuards < ActiveRecord::Migration
  def up
    transition = transition_to_guard
    ActiveRecord::Base.transaction do
      # Every ruleset has this guard applied - 100% mandatory
      StateMachineRuleSet.all.each do |ruleset|
        BatchGuard.create!(
          :state_transition => transition,
          :state_machine_rule_set => ruleset,
          :guard_type => 'block')
      end
    end
  end

  def down
    StateTransitionGuard.where('type = ?', 'BatchGuard').delete_all
  end

  def transition_to_guard
    StateTransition.
      where(:from => 'REL_PREP', :to => 'PUSH_READY').
      tap{|rel| rel.length == 1 || raise("Can't find REL_PREP => PUSH_READY transition") }.
      first
  end
end
