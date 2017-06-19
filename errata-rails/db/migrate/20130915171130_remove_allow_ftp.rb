class RemoveAllowFtp < ActiveRecord::Migration
  def self.up
    remove_column :errata_products, :allow_ftp
  end

  def self.down
    add_column :errata_products, :allow_ftp, :integer, :default => 0
  end
end
