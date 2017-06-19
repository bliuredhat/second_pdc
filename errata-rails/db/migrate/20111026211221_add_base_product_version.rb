class AddBaseProductVersion < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :base_product_version_id, :integer, :unique => true
    add_foreign_key 'product_versions', 'base_product_version_id', 'product_versions', 'id'
  end

  def self.down
    remove_column :product_versions, :base_product_version_id, :integer
  end
end
