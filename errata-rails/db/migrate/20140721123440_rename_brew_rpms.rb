class RenameBrewRpms < ActiveRecord::Migration
  def up
    change_table(:brew_rpms, :bulk => true) do |t|
      t.column :type, :string, :null => false, :default => 'BrewRpm'
      t.index :type, :name => 'index_brew_files_on_type'
      t.change :arch_id, :integer, :null => true, :default => nil
    end
    rename_table :brew_rpms, :brew_files
  end

  def down
    BrewFile.where('type != "BrewRpm"').delete_all
    rename_table :brew_files, :brew_rpms
    change_table(:brew_rpms, :bulk => true) do |t|
      t.change :arch_id, :integer, :null => false
      t.remove :type
    end
  end
end
