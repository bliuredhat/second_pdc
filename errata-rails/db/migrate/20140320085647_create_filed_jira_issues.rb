class CreateFiledJiraIssues < ActiveRecord::Migration
  def self.up
    create_table :filed_jira_issues do |t|
      t.integer :jira_issue_id, :null => false
      t.integer :errata_id, :null => false, :references => :errata_main
      t.integer :user_id, :null => false
      t.integer :state_index_id, :null => false
      t.datetime :created_at, :null => false
    end
    create_table :dropped_jira_issues do |t|
      t.integer :jira_issue_id, :null => false
      t.integer :errata_id, :null => false, :references => :errata_main
      t.integer :who_id, :null => false, :references => :users
      t.integer :state_index_id, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :dropped_jira_issues
    drop_table :filed_jira_issues
  end
end
