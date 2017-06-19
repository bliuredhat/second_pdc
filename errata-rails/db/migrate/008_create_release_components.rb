class CreateReleaseComponents < ActiveRecord::Migration
  def self.up
    create_table "release_components",
    :description => 'Mapping between releases and packages for approved components.' do |t|
      t.column "package_id", :integer, :null => false,
      :description => 'Foreign key to packages(id).'
      t.column "release_id", :integer, :null => false,
      :description => 'Foreign key to releases(id).'
      t.column "created_at", :datetime, :null => false,
      :description => 'Creation timestamp'
    end
    add_foreign_key "release_components", ["release_id"], "releases", ["id"]
    add_foreign_key "release_components", ["package_id"], "packages", ["id"]
  end

  def self.down
    drop_table :release_components
  end
end
