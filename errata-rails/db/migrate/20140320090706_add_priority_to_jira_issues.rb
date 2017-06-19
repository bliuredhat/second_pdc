class AddPriorityToJiraIssues < ActiveRecord::Migration
  def change
    add_column :jira_issues, :priority, :string, :null => false
  end
end
