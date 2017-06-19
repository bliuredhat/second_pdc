class AddDefaultFilterToUser < ActiveRecord::Migration
  def self.up
    # Actually just going to add a preferences hash, hence this file is now confusingly named..
    add_column :users, :preferences, :string, :default=>{}.to_yaml
  end

  def self.down
    remove_column :users, :preferences
  end
end
