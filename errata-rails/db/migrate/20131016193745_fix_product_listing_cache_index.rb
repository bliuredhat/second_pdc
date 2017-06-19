class FixProductListingCacheIndex < ActiveRecord::Migration
  # Make sure to run one_time_scripts:remove_obsolete_plc_entries
  # before running migration
  def self.up
    add_index :product_listing_caches, [:brew_build_id, :product_version_id], :unique => true, :name => 'plc_unique_build_product_idx'
    remove_foreign_key :product_listing_caches, 'product_listing_caches_ibfk_1'
    remove_foreign_key :product_listing_caches, 'product_listing_caches_ibfk_2'
    remove_index :product_listing_caches, :name => 'product_listing_cache_timestamp_idx'
    add_foreign_key "product_listing_caches", ["product_version_id"], "product_versions", ["id"]
    add_foreign_key "product_listing_caches", ["brew_build_id"], "brew_builds", ["id"]
 end

  def self.down
    remove_foreign_key :product_listing_caches, 'product_listing_caches_ibfk_1'
    remove_foreign_key :product_listing_caches, 'product_listing_caches_ibfk_2'
    remove_index :product_listing_caches, :name => 'plc_unique_build_product_idx'
    add_foreign_key "product_listing_caches", ["product_version_id"], "product_versions", ["id"]
    add_foreign_key "product_listing_caches", ["brew_build_id"], "brew_builds", ["id"]
    add_index "product_listing_caches", ["product_version_id", "brew_build_id", "created_at"], :name => "product_listing_cache_timestamp_idx"
  end
end
