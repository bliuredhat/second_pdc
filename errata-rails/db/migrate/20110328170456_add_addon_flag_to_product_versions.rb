class AddAddonFlagToProductVersions < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :is_rhel_addon, :boolean, :null => false, :default => false
    lacd = Product.find_by_short_name 'LACD'
    ProductVersion.update_all("is_rhel_addon = 1", ['product_id = ?', lacd])    
  end

  def self.down
    remove_column :product_versions, :is_rhel_addon
  end
end
