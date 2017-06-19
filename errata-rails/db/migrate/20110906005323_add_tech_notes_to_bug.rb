class AddTechNotesToBug < ActiveRecord::Migration
  def self.up
    # Want to store the technical notes since it's useful for ECS
    add_column :bugs, :release_notes, :text, :null => false, :default => ''

    # Let's add a last reconciled timestamp as well, might be useful
    add_column :bugs, :reconciled_at, :timestamp

  end

  def self.down
    remove_column :bugs, :release_notes
    remove_column :bugs, :reconciled_at
  end
end
