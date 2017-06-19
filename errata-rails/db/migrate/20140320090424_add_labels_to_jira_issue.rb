class AddLabelsToJiraIssue < ActiveRecord::Migration
  def self.up
    add_column :jira_issues, :labels, :string, :default => "[]", :null => false
  end

  def self.down
    remove_column :jira_issues, :labels
  end
end
