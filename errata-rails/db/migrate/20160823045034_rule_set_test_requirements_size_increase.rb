class RuleSetTestRequirementsSizeIncrease < ActiveRecord::Migration
  def up
    change_column :state_machine_rule_sets, :test_requirements, :string, :limit => 3200
  end

  def down
    change_column :state_machine_rule_sets, :test_requirements, :string # default size is 255
  end
end
