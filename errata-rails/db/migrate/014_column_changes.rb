class ColumnChanges < ActiveRecord::Migration
  def self.up
    add_column :bugs, :was_marked_on_qa, :integer, :null => false, :default => 0,
    :description => 'Flag whether a bug has already been marked as ON_QA by the errata system'
    add_column :errata_content, :doc_review_due_at, :datetime,
    :description => 'Date by which documentation review should be completed'
    
    add_column :comments, :type, :string, :null => false, :default => "Comment",
    :description => 'Type of the comment'
    

    add_column :errata_brew_mappings, 
    :spin_version, :integer, :null => false, :default => 0
    
  end

  def self.down
    
    remove_column :errata_brew_mappings, :spin_version
    remove_column :bugs, :was_marked_on_qa
    remove_column :errata_content, :doc_review_due_at
    remove_column :comments, :type
  end
end
