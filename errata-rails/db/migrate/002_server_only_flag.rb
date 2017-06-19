class ServerOnlyFlag < ActiveRecord::Migration
  def self.up
    add_column :product_versions, :is_server_only, :integer, :default => 0, :null => false,
    :description => 'RHEL 5 Specific flag for server-only products. If set, do not use -Client versions of product to search brew/compose'
  end

  def self.down
    remove_column :product_versions, :is_server_only
  end
end
