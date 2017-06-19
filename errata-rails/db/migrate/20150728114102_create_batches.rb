class CreateBatches < ActiveRecord::Migration

  def self.up
    create_table :batches, :force => true do |t|
      t.string "name", :null => false, :unique => true
      t.integer "release_id", :null => false
      t.string "description", :limit => 2000
      t.datetime "release_date"
      t.timestamps
      t.boolean "is_active", :default => true, :null => false
      t.integer :who_id, :null => false
      t.foreign_key ["release_id"], "releases", ["id"], :on_update => :restrict, :on_delete => :restrict, :name => "batches_releases_ibfk_1"
      t.foreign_key ["who_id"], "users", ["id"]
    end

    add_column :releases, :enable_batching, :boolean,
      :default => false, :null => false

    add_column :errata_main, :batch_id, :integer, :null => true
    add_column :errata_main, :is_batch_blocker, :boolean, :default => false, :null => false

    add_foreign_key(:errata_main, :batch_id, :batches, :id, :name => 'errata_main_batches_id_fk')
    add_index(:errata_main, [:batch_id], :name => 'batch_id')

  end

  def self.down
    remove_column :errata_main, :batch_id
    remove_column :errata_main, :is_batch_blocker
    remove_column :releases, :enable_batching

    drop_table :batches
  end

end
