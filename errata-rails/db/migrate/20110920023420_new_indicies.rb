class NewIndicies < ActiveRecord::Migration
  def self.up
   add_index :users, :login_name, :unique => true
    add_index :user_groups, :name, :unique => true
    add_index :errata_responsibilities, :type
    change_column :errata_products, :short_name, :string, :null => false
    add_index :errata_products, :short_name, :unique => true
    change_column :errata_types, :name, :string, :null => false, :unique => true
    change_column :errata_types, :description, :string, :null => false
    add_index :errata_types, :name, :unique => true
    add_index :errata_products, :isactive
    add_index :push_jobs, [:errata_id, :type]
    add_index :blocking_issues, :errata_id
    add_index :info_requests, :errata_id
    add_index :state_indices, :errata_id
  end

  def self.down
    remove_index :users, :login_name
    remove_index :user_groups, :name
    remove_index :errata_responsibilities, :type
    remove_index :errata_products, :short_name
    remove_index :errata_products, :isactive
    remove_index :errata_types, :name
    remove_index :push_jobs, [:errata_id, :type]
    remove_index :blocking_issues, :errata_id
    remove_index :info_requests, :errata_id
    remove_index :state_indices, :errata_id
  end
end
