class ReleaseProduct < ActiveRecord::Migration
  # update errata_groups set product_id = (select product_id from product_versions where id = product_version_id);
  def self.up
    add_column :errata_groups, :product_id, :integer,
    :description => 'Product for release group'
    add_foreign_key "errata_groups", ["product_id"], "errata_products", ["id"]
  end

  def self.down
    remove_column :errata_groups, :product_id, :integer
  end
end
