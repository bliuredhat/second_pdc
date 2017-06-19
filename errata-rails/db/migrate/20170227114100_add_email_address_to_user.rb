class AddEmailAddressToUser < ActiveRecord::Migration
  def change
    add_column :users, :email_address, :string, :default => nil, :null => true
  end
end
