class AddAllowDebuginfoToProductVersion < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :allow_rhn_debuginfo, :boolean, :default => false
  end

  def self.down
    remove_column :product_versions, :allow_rhn_debuginfo
  end
end
