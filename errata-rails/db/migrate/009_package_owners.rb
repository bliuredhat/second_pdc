class PackageOwners < ActiveRecord::Migration
  def self.up
    add_column :packages, :devel_owner_id, :integer,
    :description => 'Development owner. References users(id)'
    add_column :packages, :qe_owner_id, :integer,
    :description => 'Quality Engineering owner. References users(id)'

    add_foreign_key "packages", ["devel_owner_id"], "users", ["id"]
    add_foreign_key "packages", ["qe_owner_id"], "users", ["id"]
  end

  def self.down
    remove_column :packages, :devel_owner_id
    remove_column :packages, :qe_owner_id
  end
end
