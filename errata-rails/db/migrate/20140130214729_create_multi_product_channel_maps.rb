class CreateMultiProductChannelMaps < ActiveRecord::Migration
  def self.up
    create_table :multi_product_channel_maps, :foreign_keys => {:auto_create => false} do |t|
      t.integer :origin_channel_id, :null => false
      t.integer :origin_product_version_id, :null => false
      t.integer :destination_channel_id, :null => false
      t.integer :destination_product_version_id, :null => false
      t.integer :package_id, :null => false
      t.integer :user_id, :null => false
      t.timestamps
    end

    add_column :errata_main, :supports_multiple_product_destinations, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :errata_main, :supports_multiple_product_destinations
    drop_table :multi_product_channel_maps
  end
end
