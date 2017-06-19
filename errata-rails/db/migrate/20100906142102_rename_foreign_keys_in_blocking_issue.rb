class RenameForeignKeysInBlockingIssue < ActiveRecord::Migration
  def self.up
    rename_column :blocking_issues, :who, :user_id
    rename_column :blocking_issues, :blocking_role, :blocking_role_id
  end

  def self.down
    rename_column :blocking_issues, :user_id, :who
    rename_column :blocking_issues, :blocking_role_id, :blocking_role
  end
end