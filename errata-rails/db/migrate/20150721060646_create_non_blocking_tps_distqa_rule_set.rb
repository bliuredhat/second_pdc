class CreateNonBlockingTpsDistqaRuleSet < ActiveRecord::Migration
  def up
    # If it seems to exist already then let's do nothing
    return say "Rule set '#{rule_set_name}' exists. Won't try to add it." if StateMachineRuleSet.exists?(:name => rule_set_name)
    create_new_rule_set
  end

  def down
    # Removing it could cause problems if it's used by anything so let's not
    say "Won't try to remove rule set '#{rule_set_name}'. Remove manually if required."
  end

  private
  # Do the following works
  # - Create new a rule set as a copy of default.
  # - Set the TPS DistQA guards to 'info' (instead of 'block').
  # - Switch TPS DistQA scheduling mode to manual.
  # - Use this newly created rule for RHEL-7.2.0 release
  def create_new_rule_set
    ActiveRecord::Base.transaction do
      new_rule_set = StateMachineRuleSet.default_rule_set.create_duplicate_rule_set!(rule_set_name, rule_set_descr)
      new_rule_set.state_transition_guards.where(:type => "TpsRhnqaGuard").update_all(:guard_type => 'info')
      new_rule_set.test_requirements << "TpsDistQAManualOnly"

      if rhel_7_2_0
        new_rule_set.releases << rhel_7_2_0
      else
        # RHEL-7.2.0 might not already existed in the development and test db so print a warning
        # message instead of terminating the migration.
        say "Couldn't add 'RHEL-7.2.0' release to the '#{rule_set_name} state machine rule set " +
         "because it doesn't exist. You might need to add it to this rule manually later."
      end
      new_rule_set.save!
    end
  end

  def rhel_7_2_0
    Release.find_by_name('RHEL-7.2.0')
  end

  def rule_set_name
    'Optional TPS DistQA'
  end

  def rule_set_descr
    'Non-blocking TPS DistQA and schedule TPS DistQA manually. Otherwise, same as default rule set.'
  end
end
