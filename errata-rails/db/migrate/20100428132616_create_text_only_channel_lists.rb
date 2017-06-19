class CreateTextOnlyChannelLists < ActiveRecord::Migration
  def self.up
    create_table :text_only_channel_lists do |t|
      t.integer :errata_id, :null => false
      t.text :channel_list, :null => false
      t.timestamps
    end
    add_foreign_key 'text_only_channel_lists', ['errata_id'], 'errata_main', ['id']
    add_column :errata_main, :text_only, :boolean, :null => false, :default => 0
  end

  def self.down
    drop_column :errata_main, :text_only
    drop_table :text_only_channel_lists
  end
end
