class AddErrataBrewMappingToRmpdiff < ActiveRecord::Migration
  def self.up
    add_column :rpmdiff_runs, :errata_brew_mapping_id, :integer
    add_foreign_key "rpmdiff_runs", ["errata_brew_mapping_id"], "errata_brew_mappings", ["id"]
  end

  def self.down
    remove_column :rpmdiff_runs, :errata_brew_mapping_id
  end
end
