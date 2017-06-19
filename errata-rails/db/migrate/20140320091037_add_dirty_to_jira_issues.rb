class AddDirtyToJiraIssues < ActiveRecord::Migration
  def self.up
    add_column :jira_issues, :dirty, :boolean, :default => false, :null => false, :index => true
  end

  def self.down
    remove_column :jira_issues, :dirty
  end
end
