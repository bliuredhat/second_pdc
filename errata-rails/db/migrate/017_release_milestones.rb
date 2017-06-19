class ReleaseMilestones < ActiveRecord::Migration
  def self.up
    create_table :release_milestones, 
    :description => "Release milestone dates" do |t|
      t.column "name", :string, :null => false, 
      :description => "Name of the milestone"
      t.column "release_id", :integer, :null => false,
      :description => "Release the milestone is for."
      t.column "due_date", :date, :null => false, 
      :description => "Date the milestone is due."
    end

    add_foreign_key "release_milestones", ["release_id"], "releases", ["id"]
  end

  def self.down
    drop_table :release_milestones
  end
end
