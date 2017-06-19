class AddArchiveTypeToBrewMappings < ActiveRecord::Migration
  def up
    add_column :errata_brew_mappings, :brew_archive_type_id, :integer, :null => true
    add_foreign_key :errata_brew_mappings, :brew_archive_type_id, :brew_archive_types, :id, :name => 'errata_brew_mappings_archive_type_ibfk'
  end

  def down
    remove_column :errata_brew_mappings, :brew_archive_type_id
  end
end
