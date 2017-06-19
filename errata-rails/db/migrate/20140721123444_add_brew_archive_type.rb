class AddBrewArchiveType < ActiveRecord::Migration
  def change
    create_table :brew_archive_types do |t|
      t.column :extensions, :string, :null => false
      t.column :name, :string, :null => false, :index => {:unique => true}
      t.column :description, :text, :null => true
    end
  end
end
