class CreateJiraIssues < ActiveRecord::Migration
  def self.up
    create_table :jira_security_levels do |t|
      t.string :name, :null => false
      t.integer :id_jira, :null => false, :unique => true
    end
    create_table :jira_issues do |t|
      t.integer :id_jira, :null => false, :unique => true
      t.string :key, :null => false, :unique => true
      t.string :summary, :null => false, :limit => 4000
      t.string :status, :null => false
      t.integer :jira_security_level_id
      t.timestamp :updated, :null => false
    end
  end

  def self.down
    drop_table :jira_issues
    drop_table :jira_security_levels
  end
end
