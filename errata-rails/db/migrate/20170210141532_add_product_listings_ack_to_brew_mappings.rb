class AddProductListingsAckToBrewMappings < ActiveRecord::Migration
  def up
    add_column :errata_brew_mappings, :product_listings_mismatch_ack, :boolean, :default => false
  end

  def down
    remove_column :errata_brew_mappings, :product_listings_mismatch_ack
  end
end
