class AddDockerMetaRepoGuards < ActiveRecord::Migration
  def up
    transition = transition_to_guard
    ActiveRecord::Base.transaction do
      StateMachineRuleSet.all.reject{|rs| rs.name == 'Unrestricted'}.each do |ruleset|
        DockerMetaRepoGuard.create!(
          :state_transition => transition,
          :state_machine_rule_set => ruleset,
          :guard_type => 'block')
      end
    end
  end

  def down
    StateTransitionGuard.where('type = ?', 'DockerMetaRepoGuard').delete_all
  end

  def transition_to_guard
    StateTransition.
      where(:from => 'NEW_FILES', :to => 'QE').
      tap{|rel| rel.length == 1 || raise("Can't find NEW_FILES => QE transition") }.
      first
  end
end
