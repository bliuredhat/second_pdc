class AddArchiveTypeIdToBrewFiles < ActiveRecord::Migration
  def up
    add_column :brew_files, :brew_archive_type_id, :integer, :null => true
    add_foreign_key :brew_files, :brew_archive_type_id, :brew_archive_types, :id, :name => 'brew_files_archive_type_ibfk'
  end

  def down
    remove_column :brew_files, :brew_archive_type_id
  end
end
