class AddRankToBrewFileMeta < ActiveRecord::Migration
  def up
    add_column :brew_file_meta, :rank, :integer, :default => nil, :null => true

    # This migration also makes a null title permissible at the DB
    # layer, because the application wants to be able to set rank and
    # title independently in separate actions.
    #
    # The application layer now needs to check if a BrewFileMeta is
    # complete.
    change_column :brew_file_meta, :title, :string, :default => nil, :null => true
  end

  def down
    change_column :brew_file_meta, :title, :string, :default => "", :null => false
    remove_column :brew_file_meta, :rank
  end
end
