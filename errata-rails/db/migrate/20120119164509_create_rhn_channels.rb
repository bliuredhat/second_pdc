class CreateRhnChannels < ActiveRecord::Migration
  def self.up
    rename_column :channels, :type, :ctype
    rename_table :channels, :backup_channels

    create_table :channels do |t|
      t.string :name, :null => false, :unique => true
      t.string :type, :null => false
      t.integer :variant_id, :null => false
      t.integer :arch_id, :null => false
      t.integer :product_version_id, :null => false
      t.string :cdn_path
      t.timestamps
    end
    add_foreign_key 'channels', 'arch_id', 'errata_arches', 'id'
    add_foreign_key 'channels', 'variant_id', 'errata_versions', 'id'
    add_foreign_key 'channels', 'product_version_id', 'product_versions', 'id'

    create_table :channel_links do |t|
      t.integer :channel_id, :null => false
      t.integer :product_version_id, :null => false
      t.integer :variant_id, :null => false
      t.timestamps
    end
    add_foreign_key 'channel_links', 'variant_id', 'errata_versions', 'id'
    add_foreign_key 'channel_links', 'product_version_id', 'product_versions', 'id'
    add_foreign_key 'channel_links', 'channel_id', 'channels', 'id'
  end

  def self.down
    drop_table :channel_links
    drop_table :channels
    rename_column :backup_channels, :ctype, :type
    rename_table :backup_channels, :channels
  end
end
