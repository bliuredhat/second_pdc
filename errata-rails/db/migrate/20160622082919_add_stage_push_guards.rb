class AddStagePushGuards < ActiveRecord::Migration
  def up
    transition = transition_to_guard
    ActiveRecord::Base.transaction do
      StateMachineRuleSet.all.reject{|rs| rs.name == 'Unrestricted' || rs.name =~ /^Optional stage/}.each do |ruleset|
        StagePushGuard.create!(
          :state_transition => transition,
          :state_machine_rule_set => ruleset,
          :guard_type => 'block')
      end
    end
  end

  def down
    StateTransitionGuard.where('type = ?', 'StagePushGuard').delete_all
  end

  def transition_to_guard
    StateTransition.
      where(:from => 'QE', :to => 'REL_PREP').
      tap{|rel| rel.length == 1 || raise("Can't find QE => REL_PREP transition") }.
      first
  end
end
