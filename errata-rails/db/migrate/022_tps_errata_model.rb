class TpsErrataModel < ActiveRecord::Migration
  def self.up
    add_column :tpsjobs, :in_queue, :integer, :null => false, :default => 0,
    :description => 'True if the tps job is in the active job queue for processing'
    add_column :tpsjobs, :errata_id, :integer, :null => false, :default => 0,
    :description => 'Foreign key to errata_main.id'
    add_column :tpsjobs, :product_variant_id, :integer, :default => 0,
    :description => 'Foreign key to errata_versions.id'
    add_column :tpsjobs, :rhn_channel_id, :integer, :default => 0,
    :description => 'Foreign key to rhn_channels.id'
    
  end

  def self.down
    remove_column :tpsjobs, :in_queue
    remove_column :tpsjobs, :errata_id
    remove_column :tpsjobs, :product_variant_id
    remove_column :tpsjobs, :rhn_channel_id
  end
end
