class AddChannelToTpsJobs < ActiveRecord::Migration
  def self.up
    add_column :tpsjobs, :channel_was_set, :boolean, :null => false, :default => false
    add_column :tpsjobs, :channel_id, :integer

    add_foreign_key 'tpsjobs', 'channel_id', 'channels', 'id'
  end

  def self.down
    remove_column :tpsjobs, :channel_was_set
    remove_column :tpsjobs, :channel_id
  end
end
