class CreateBrewFileMeta < ActiveRecord::Migration
  def up
    create_table :brew_file_meta do |t|
      t.references :errata, :null => false
      t.references :brew_file, :null => false
      t.string :title, :null => false, :default => ''
    end
    add_foreign_key :brew_file_meta, [:errata_id], :errata_main, [:id],
      :name => 'brew_file_meta_errata_ibfk'
    add_foreign_key :brew_file_meta, [:brew_file_id], :brew_files, [:id],
      :name => 'brew_file_meta_brew_file_ibfk'
  end

  def down
    drop_table :brew_file_meta
  end
end
