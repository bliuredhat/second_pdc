class CreateOptionalChannelToLayeredMaps < ActiveRecord::Migration
  def self.up
    create_table :optional_channel_to_layered_maps do |t|
      t.integer :optional_channel_id, :null => false
      t.integer :layered_channel_id, :null => false
      t.integer :package_id, :null => false
      t.timestamps
    end
    add_foreign_key 'optional_channel_to_layered_maps', 'optional_channel_id', 'channels', 'id'
    add_foreign_key 'optional_channel_to_layered_maps', 'layered_channel_id', 'channels', 'id'
  end

  def self.down
    drop_table :optional_channel_to_layered_maps
  end
end
