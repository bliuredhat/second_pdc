class AddVerifiedToBugzilla < ActiveRecord::Migration
  def self.up
    add_column :bugs, :verified, :string, :null => false, :default => ''
  end

  def self.down
    remove_column :bugs, :verified
  end
end
