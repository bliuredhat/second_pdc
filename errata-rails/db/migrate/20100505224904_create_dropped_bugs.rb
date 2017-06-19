class CreateDroppedBugs < ActiveRecord::Migration
  def self.up
    create_table :dropped_bugs, :description => 'Bugs removed from an advisory; for auditing purposes' do |t|
      t.integer :errata_id, :null => false,
      :description => "Foreign key to errata_main(id)"
      t.integer :bug_id, :null => false,
      :description => "Foreign key to bugs(id)"
      t.integer :who, :null => false,
      :description => "Foreign key to users(id)"
      t.integer :state_index_id, :null => false,
      :description => "State index when bug removed from advisory"
      t.timestamps
    end
    add_foreign_key "dropped_bugs", ["state_index_id"], "state_indices", ["id"]
    add_foreign_key "dropped_bugs", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "dropped_bugs", ["bug_id"], "bugs", ["id"]
    add_foreign_key "dropped_bugs", ["who"], "users", ["id"]
  end

  def self.down
    drop_table :dropped_bugs
  end
end
