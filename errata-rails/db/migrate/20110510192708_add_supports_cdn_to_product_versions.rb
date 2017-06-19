class AddSupportsCdnToProductVersions < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :supports_cdn, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :product_versions, :supports_cdn
  end
end
