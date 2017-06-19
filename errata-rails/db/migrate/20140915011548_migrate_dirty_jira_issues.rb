class MigrateDirtyJiraIssues < ActiveRecord::Migration
  def up
    ActiveRecord::Base.transaction do
      JiraIssue.select('id_jira').where(:dirty => true).each do |jira_issue|
        DirtyJiraIssue.create!(:record_id => jira_issue.id_jira, :last_updated => Time.now)
      end
    end

    remove_column :jira_issues, :dirty
  end

  def down
    add_column :jira_issues, :dirty, :boolean, :default => false, :null => false, :index => true

    dirty_jira_issue_ids = DirtyJiraIssue.pluck("distinct record_id")
    JiraIssue.where(:id_jira => dirty_jira_issue_ids).update_all(:dirty => true)
  end
end
