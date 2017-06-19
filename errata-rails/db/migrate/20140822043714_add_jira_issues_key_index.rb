class AddJiraIssuesKeyIndex < ActiveRecord::Migration
  def up
    add_index :jira_issues, [:key], :name => 'jira_issues_key_idx'
  end

  def down
    remove_index :jira_issues, :name => 'jira_issues_key_idx'
  end
end
