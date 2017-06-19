class DropTpsSystems < ActiveRecord::Migration
  def up
    remove_column :tpsjobs, :tps_system_id
    drop_table :tps_systems
  end

  def down
    create_table :tps_systems do |t|
      t.integer :rhel_release_id, :null => false
      t.integer :version_id, :null => false
      t.integer :arch_id, :null => false
      t.string :description
      t.integer :enabled, :null => false, :default => 1
    end
    add_foreign_key "tps_systems", ["rhel_release_id"], "rhel_releases", ["id"]
    add_foreign_key "tps_systems", ["version_id"], "errata_versions", ["id"]
    add_foreign_key "tps_systems", ["arch_id"], "errata_arches", ["id"]

    add_column :tpsjobs, :tps_system_id, :integer, :references => :tps_systems
  end
end
