class ResponsibilityMappings < ActiveRecord::Migration
  def self.up
    add_column :errata_main, :rating, :integer, :null => false, :default => 0
    add_column :errata_main, :docs_responsibility_id, :integer, :null => false, :default => 1
    add_column :errata_main, :quality_responsibility_id, :integer, :null => false, :default => 2
    add_column :errata_main, :devel_responsibility_id, :integer, :null => false, :default => 3

    add_foreign_key "errata_main", ["docs_responsibility_id"], "errata_responsibilities",  ["id"]
    add_foreign_key "errata_main", ["quality_responsibility_id"], "errata_responsibilities",  ["id"]
    add_foreign_key "errata_main", ["devel_responsibility_id"], "errata_responsibilities",  ["id"]

    add_column :packages, :docs_responsibility_id, :integer, :null => false, :default => 1
    add_column :packages, :quality_responsibility_id, :integer, :null => false, :default => 2
    add_column :packages, :devel_responsibility_id, :integer, :null => false, :default => 3

    add_foreign_key "packages", ["docs_responsibility_id"], "errata_responsibilities",  ["id"]
    add_foreign_key "packages", ["quality_responsibility_id"], "errata_responsibilities",  ["id"]
    add_foreign_key "packages", ["devel_responsibility_id"], "errata_responsibilities",  ["id"]
  end

  def self.down
    remove_column :errata_main, :rating
    remove_column :errata_main, :docs_responsibility_id
    remove_column :errata_main, :quality_responsibility_id
    remove_column :errata_main, :devel_responsibility_id

    remove_column :packages, :docs_responsibility_id
    remove_column :packages, :quality_responsibility_id
    remove_column :packages, :devel_responsibility_id
  end
end
