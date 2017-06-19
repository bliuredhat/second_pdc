#
# The new rule set will be used by Openshift
# See Bug 1182839
#
class AddNonBlockingTpsRuleSet < ActiveRecord::Migration
  def up
    # If it seems to exist already then let's do nothing
    return puts "Rule set '#{rule_set_name}' exists. Won't try to add it." if StateMachineRuleSet.exists?(:name => rule_set_name)
    create_new_rule_set
  end

  def down
    # Removing it could cause problems if it's used by anything so let's not
    puts "Won't try to remove rule set '#{rule_set_name}'. Remove manually if required."
  end

  private

  # Create new a rule set as a copy of default then set the two TPS guards to 'info' (instead of 'block')
  def create_new_rule_set
    ActiveRecord::Base.transaction do
      new_rule_set = StateMachineRuleSet.default_rule_set.create_duplicate_rule_set!(rule_set_name, rule_set_descr)
      new_rule_set.state_transition_guards.where(:type => %w[TpsGuard TpsRhnqaGuard]).update_all(:guard_type => 'info')
    end
  end

  def rule_set_name
    'Non-blocking TPS'
  end

  def rule_set_descr
    'Same as Default rule set but with TPS set to non-blocking'
  end

end
