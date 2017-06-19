class AddInternalFlagToProducts < ActiveRecord::Migration
  def self.up
    add_column :errata_products, :is_internal, :boolean, :null => false, :default => false
  end

  def self.down
    add_column :errata_products, :is_internal
  end
end
