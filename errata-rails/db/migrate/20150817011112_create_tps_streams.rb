class CreateTpsStreams < ActiveRecord::Migration
  def up
    create_table :tps_streams do |t|
      t.string :name, :null => false
      t.boolean :active, :null => false
      # parent_id refers back to this table id itself. Don't want to add a intergrity check for this
      # because it is hard to workout which records should be added or deleted first during the sync.
      # Simply trust the data from TPS server.
      t.references :parent, :index => true
      t.references :tps_stream_type, :references => :tps_stream_types, :null => false, :index => true
      t.references :tps_variant, :references => :tps_variants, :null => false, :index => true
    end
    say "Syncing information with TPS server (#{Tps::TPS_SERVER})..."
    Tps::SyncTpsStreams.sync
    say "Sync complete."
  end

  def down
    drop_table :tps_streams
  end
end
