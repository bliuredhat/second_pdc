class AddRpmdiffReviewToWorkflows < ActiveRecord::Migration
  def up
    qr = StateTransition.find_by_from_and_to 'QE', 'REL_PREP'

    # every rule which currently has an RpmdiffGuard gets a non-mandatory RpmdiffReviewGuard
    StateMachineRuleSet.transaction do
      StateMachineRuleSet\
        .all\
        .reject{|ruleset| ruleset.state_transition_guards.where(:type => 'RpmdiffGuard').empty? }\
        .each do |ruleset|
        RpmdiffReviewGuard.create!(:state_machine_rule_set => ruleset, :guard_type => 'info', :state_transition => qr)
      end
    end
  end

  def down
    RpmdiffReviewGuard.delete_all
  end
end
