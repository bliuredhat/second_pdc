class AddActiveToDefaultSolution < ActiveRecord::Migration
  def self.up
    add_column :default_solutions, :active, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :default_solutions, :active
  end
end
