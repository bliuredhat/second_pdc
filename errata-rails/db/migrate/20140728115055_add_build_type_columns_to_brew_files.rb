class AddBuildTypeColumnsToBrewFiles < ActiveRecord::Migration
  def up
    change_table(:brew_files, :bulk => true) do |t|
      # for win builds
      t.column :relpath, :string, :null => true

      # for maven builds
      t.column :maven_groupId, :string, :null => true
      t.column :maven_artifactId, :string, :null => true
    end
  end

  def down
    change_table(:brew_files, :bulk => true) do |t|
      t.remove :maven_artifactId
      t.remove :maven_groupId
      t.remove :relpath
    end
  end
end
