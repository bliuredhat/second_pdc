class AddIdJiraIndex < ActiveRecord::Migration
  def up
    add_index :jira_issues, [:id_jira], :name => 'jira_issues_id_jira_idx', :unique => true
  end

  def down
    remove_index :jira_issues, :name => 'jira_issues_id_jira_idx'
  end
end