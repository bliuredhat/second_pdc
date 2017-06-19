class CreateProductListingCaches < ActiveRecord::Migration
  def self.up
    create_table :product_listing_caches, 
    :description => "Cache of calls to brew.getProductListings" do |t|
      t.column "product_version_id", :integer, :null => false,
      :description => "Foreign key to product_versions(id)."
      t.column "brew_build_id", :integer, :null => false,
      :description => "Foreign key to brew_builds(id)."
      t.column "created_at", :datetime, :null => false, 
      :description => "Creation timestamp."
      t.column "cache", :text, :null => false, 
      :description => "Hash dumped as YAML."
    end

    add_foreign_key "product_listing_caches", ["product_version_id"], "product_versions", ["id"]
    add_foreign_key "product_listing_caches", ["brew_build_id"], "brew_builds", ["id"]
    add_index "product_listing_caches", ["product_version_id", "brew_build_id", "created_at"], :name => "product_listing_cache_timestamp_idx"
    
  end

  def self.down
    drop_table :product_listing_caches
  end
end
