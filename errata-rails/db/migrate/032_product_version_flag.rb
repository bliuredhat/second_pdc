class ProductVersionFlag < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :enabled, :integer, :null => false, :default => 1
  end

  def self.down
  end
end
