class AddDirtyToBugs < ActiveRecord::Migration
  def self.up
    add_column :bugs, :dirty, :boolean, :default => false, :null => false, :index => true
  end

  def self.down
    remove_column :bugs, :dirty
  end
end
