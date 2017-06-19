class AddFlagPrefixToProduct < ActiveRecord::Migration
  def self.up
    add_column :errata_products, :cdw_flag_prefix, :string, :default => nil
  end

  def self.down
    remove_column :errata_products, :cdw_flag_prefix
  end
end
