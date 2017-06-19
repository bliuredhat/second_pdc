class UserGroupsToRoles < ActiveRecord::Migration
  def self.up
    rename_table :user_groups, :roles
    remove_foreign_key 'user_group_map', 'user_group_map_ibfk_1'
    remove_foreign_key 'user_group_map', 'user_group_map_ibfk_2'
    rename_column :user_group_map, :group_id, :role_id
    rename_table :user_group_map, :roles_users
  end

  def self.down
   rename_table :roles_users, :user_group_map
   rename_column :user_group_map, :role_id, :group_id
   rename_table :roles, :user_groups
  end
end
