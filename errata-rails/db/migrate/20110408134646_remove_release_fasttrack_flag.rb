class RemoveReleaseFasttrackFlag < ActiveRecord::Migration
  def self.up
    remove_column :releases, :is_fasttrack
  end

  def self.down
  end
end
