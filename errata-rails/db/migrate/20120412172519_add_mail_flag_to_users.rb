class AddMailFlagToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :receives_mail, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :users, :receives_mail
  end
end

