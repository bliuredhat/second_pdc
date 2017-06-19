class CreateSrpmCdnPaths < ActiveRecord::Migration
  def self.up
    create_table :srpm_cdn_paths do |t|
      t.integer :variant_id, :null => false
      t.string :path, :null => false
      t.string :path_type, :null => false
      t.timestamps
    end
    add_foreign_key 'srpm_cdn_paths', ['variant_id'], 'errata_versions', 'id'
  end

  def self.down
    drop_table :srpm_cdn_paths
  end
end
