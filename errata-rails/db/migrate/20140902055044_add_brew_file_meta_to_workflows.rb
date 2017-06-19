class AddBrewFileMetaToWorkflows < ActiveRecord::Migration
  def up
    transition = StateTransition.find_by_from_and_to 'NEW_FILES', 'QE'

    # every rule which currently has a BuildGuard gets a BrewFileMetaGuard
    StateMachineRuleSet.transaction do
      StateMachineRuleSet\
        .all\
        .reject{|ruleset| ruleset.state_transition_guards.where(:type => 'BuildGuard').empty? }\
        .each do |ruleset|
        BrewFileMetaGuard.create!(:state_machine_rule_set => ruleset, :guard_type => 'block', :state_transition => transition)
      end
    end
  end

  def down
    BrewFileMetaGuard.delete_all
  end
end
