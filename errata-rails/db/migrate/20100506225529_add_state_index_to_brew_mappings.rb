class AddStateIndexToBrewMappings < ActiveRecord::Migration
  def self.up
    add_column :errata_brew_mappings, :updated_at, :datetime
    add_column :errata_brew_mappings, :added_index_id, :integer
    add_column :errata_brew_mappings, :removed_index_id, :integer
    add_foreign_key "errata_brew_mappings", ["added_index_id"], "state_indices", ["id"]
    add_foreign_key "errata_brew_mappings", ["removed_index_id"], "state_indices", ["id"]
  end

  def self.down
    drop_column :errata_brew_mappings, :updated_at
    drop_column :errata_brew_mappings, :added_index_id
    drop_column :errata_brew_mappings, :removed_index_id
  end
end
