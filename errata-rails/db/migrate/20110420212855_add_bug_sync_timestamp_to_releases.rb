class AddBugSyncTimestampToReleases < ActiveRecord::Migration
  def self.up
    add_column :releases, :bugs_last_synched_at, :datetime
  end

  def self.down
    remove_column :releases, :bugs_last_synched_at
  end
end
