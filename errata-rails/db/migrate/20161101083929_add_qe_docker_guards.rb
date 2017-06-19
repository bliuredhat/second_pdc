class AddQeDockerGuards < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      StateMachineRuleSet.all.reject{|rs| rs.name == 'Unrestricted'}.each do |ruleset|
        DockerGuard.create!(
          :state_transition => transition,
          :state_machine_rule_set => ruleset,
          :guard_type => 'block')
      end
    end
  end

  def down
    DockerGuard.where(:state_transition_id => transition).delete_all
  end

  def transition
    StateTransition.
      where(:from => 'NEW_FILES', :to => 'QE').
      tap{|rel| rel.length == 1 || raise("Can't find NEW_FILES => QE transition") }.
      first
  end
end
