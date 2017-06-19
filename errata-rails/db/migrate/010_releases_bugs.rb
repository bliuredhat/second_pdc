class ReleasesBugs < ActiveRecord::Migration
  def self.up
    create_table "bugs_releases", 
    :description => 'Mapping between releases and bugs for approved bugs.' do |t|
      t.column "release_id", :integer, :null => false,
      :description => 'Foreign key to releases(id).'
      t.column "bug_id", :integer, :null => false,
      :description => 'Foreign key to bugs(id).'
    end
    
    add_foreign_key "bugs_releases", ["release_id"], "releases", ["id"]
    add_foreign_key "bugs_releases", ["bug_id"], "bugs", ["id"]
    
  end

  def self.down
    drop_table :bugs_releases
  end
end
