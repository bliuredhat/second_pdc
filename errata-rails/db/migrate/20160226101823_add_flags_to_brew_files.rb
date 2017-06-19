class AddFlagsToBrewFiles < ActiveRecord::Migration
  def change
    add_column :brew_files, :flags, :string, :null => true
  end
end
