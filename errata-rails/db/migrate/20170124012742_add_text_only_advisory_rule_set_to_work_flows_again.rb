class AddTextOnlyAdvisoryRuleSetToWorkFlowsAgain < ActiveRecord::Migration

  # This migration has been done once by AddTextOnlyAdvisoryRuleSetToWorkFlows
  # but the TextOnlyAdvisoryGuards were removed soon to temporarly solve the
  # urgent request from the middle products.
  # See https://engineering.redhat.com/rt/Ticket/Display.html?id=420915
  # Now we have the patch(4dd35aec) for this issue so let's recreate the
  # TextOnlyAdvisoryGuards by this migration instead of manually creating
  # on prod db.
  def up
    guards = TextOnlyAdvisoryGuard.all
    if guards.none?
      transition = StateTransition.find_by_from_and_to 'QE', 'REL_PREP'
      ActiveRecord::Base.transaction do
        # Every ruleset has this guard applied - 100% mandatory
        StateMachineRuleSet.all.each do |ruleset|
          TextOnlyAdvisoryGuard.create!(:state_machine_rule_set => ruleset,
                                        :guard_type => 'block',
                                        :state_transition => transition)
          puts "TextOnlyAdvisoryGuard has been created for #{ruleset.name} StateMachineRuleSet."
        end
      end
    else
      puts "#{guards.count} TextOnlyAdvisoryGuard already exist"
      puts "Quit the migration"
    end
  end

  def down
    deleted = TextOnlyAdvisoryGuard.delete_all
    puts "All #{deleted} TextOnlyAdvisoryGuards have been deleted"
  end
end
