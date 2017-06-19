class AddBugColumns < ActiveRecord::Migration
  def self.up
    add_column :bugs, :priority, :string, :null => false, :default => 'med'
    add_column :bugs, :bug_severity, :string, :null => false, :default => 'med'
    add_column :bugs, :qa_whiteboard, :string, :null => false, :default => ''
    add_column :bugs, :keywords, :string, :null => false, :default => ''
    add_column :bugs, :issuetrackers, :string, :null => false, :default => ''
    add_column :bugs, :pm_score, :integer, :null => false, :default => 0
    add_column :bugs, :is_blocker, :integer, :null => false, :default => 0
    add_column :bugs, :is_exception, :integer, :null => false, :default => 0
    add_column :bugs, :flags, :string, :null => false, :default => ''
    
  end

  def self.down
    
  end
end
