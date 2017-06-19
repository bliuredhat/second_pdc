class AddIdBrewToBrewFiles < ActiveRecord::Migration
  # This migration changes semantics of the primary key of the brew_files table.
  #
  # Before migration:
  #  - id belongs to brew, is a brew RPM ID or brew archive ID
  #  - table can't store an RPM and archive with the same brew ID (bug 1189351)
  #
  # After migration:
  #  - id belongs to ET, an arbitrary unique number
  #  - id_brew belongs to brew, it is the ID of a brew RPM or brew archive (depending on the value of "type")
  def up
    change_table(:brew_files) do |t|
      t.column :id_brew, :integer, :null => true, :default => nil
      t.index :id_brew, :name => 'index_brew_files_on_id_brew'

      BrewFile.update_all('id_brew = id')

      t.change :id_brew, :integer, :null => false
    end
  end

  def down
    if BrewFile.where('id != id_brew').exists?
      # Cannot safely automatically roll back in this case.
      raise ActiveRecord::IrreversibleMigration.new(<<-'eos'.strip_heredoc)
        Brew files have been imported since this migration was run.
        The migration can't be automatically rolled back in this case.
        The following data may need to be cleaned:

          BrewFile.where('id != id_brew')
eos
    end

    change_table(:brew_files, :bulk => true) do |t|
      t.remove :id_brew
    end
  end
end
