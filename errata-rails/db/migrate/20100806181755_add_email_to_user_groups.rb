class AddEmailToUserGroups < ActiveRecord::Migration
  def self.up
    add_column :user_groups, :blocking_issue_target, :string
    add_column :user_groups, :info_request_target, :string
  end

  def self.down
    remove_column :user_groups, :blocking_issue_target
    remove_column :user_groups, :info_request_target
  end
end
