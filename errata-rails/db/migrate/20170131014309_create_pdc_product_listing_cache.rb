class CreatePdcProductListingCache < ActiveRecord::Migration
  def change

    create_table :pdc_product_listing_caches do |t|
      t.integer :pdc_release_id, references: :pdc_resources
      t.integer :brew_build_id, references: :brew_builds
      t.text :cache, limit: 16.megabytes - 1.byte
      t.timestamps
    end

  end
end
