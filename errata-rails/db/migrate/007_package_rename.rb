class PackageRename < ActiveRecord::Migration
  def self.up
    rename_table :errata_packages, :packages
    rename_table :errata_groups, :releases
  end

  def self.down
    rename_table :packages, :errata_packages
    rename_table :releases, :errata_groups
  end
end
