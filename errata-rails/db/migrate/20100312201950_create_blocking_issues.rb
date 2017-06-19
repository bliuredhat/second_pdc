class CreateBlockingIssues < ActiveRecord::Migration
  def self.up
    create_table :blocking_issues do |t|
      t.integer :errata_id, :null => false
      t.integer :state_index_id, :null => false
      t.integer :who, :null => false
      t.integer :blocking_role, :null => false
      t.string  :summary, :null => false
      t.string  :description, :null => false, :limit => 4000
      t.boolean :is_active, :null => false
      t.timestamps
    end
    add_column :comments, :blocking_issue_id, :integer
    add_foreign_key "comments", ["blocking_issue_id"], "blocking_issues", ["id"]
    
  end

  def self.down
    remove_column :comments, :blocking_issue_id
    drop_table :blocking_issues
  end
end
