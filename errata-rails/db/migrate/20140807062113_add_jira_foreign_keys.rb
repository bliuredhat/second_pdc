class AddJiraForeignKeys < ActiveRecord::Migration
  KEYS = [
    [:dropped_jira_issues, :jira_issue_id,          :jira_issues,          :id],
    [:dropped_jira_issues, :state_index_id,         :state_indices,        :id],
    [:filed_jira_issues,   :jira_issue_id,          :jira_issues,          :id],
    [:filed_jira_issues,   :user_id,                :users,                :id],
    [:filed_jira_issues,   :state_index_id,         :state_indices,        :id],
    [:jira_issues,         :jira_security_level_id, :jira_security_levels, :id],
  ]

  def fkey_name(tbl,col)
    "#{tbl}_#{col}_fk"
  end

  def up
    KEYS.each do |tbl,col,ftable,fcol|
      add_foreign_key tbl, col, ftable, fcol, :name => fkey_name(tbl,col)
    end
  end

  def down
    KEYS.reverse.each do |tbl,col,ftable,fcol|
      remove_foreign_key tbl, fkey_name(tbl, col)
    end
  end
end
