class AddSecurityLevelEffect < ActiveRecord::Migration
  def self.up
    add_column :jira_security_levels, :effect, :string, :limit => 64, :null => false
  end

  def self.down
    remove_column :jira_security_levels, :effect
  end
end
