class AddOvalFlagToProductVersions < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :is_oval_product, :boolean, :null => false, :default => false
    ProductVersion.update_all(['is_oval_product = ?', true], ["name in (?)", ['RHEL-3','RHEL-4','RHEL-5','RHEL-5.6.Z','RHEL-6']])
  end

  def self.down
    drop_column :product_versions, :is_oval_product
  end
end
