class ChangeBugzillaTimestamp < ActiveRecord::Migration
  def self.up
    rename_column :bugs, :updated_at, :last_updated
  end

  def self.down
    rename_column :bugs, :last_updated, :updated_at
  end
end
