class UserEnabled < ActiveRecord::Migration
  def self.up
    add_column :users, :enabled, :integer, :default => 1, :null => false,
    :description => 'Set to 1 if user account is enabled'
  end

  def self.down
    remove_column :users, :enabled
  end
end
