class CreateFiledBugs < ActiveRecord::Migration
  # insert into filed_bugs (errata_id, bug_id, created_at, user_id) select m.id, b.bug_id, b.created_at, m.reporter from errata_main m, errata_bug_map b where m.id = b.errata_id;
  
  def self.up
    create_table :filed_bugs, 
    :description => 'Mapping between errata and the bugs filed for that errata. Replaces errata_bug_map' do |t|
      t.column "errata_id", :integer, :null => false,
      :description => "Foreign key to errata_main(id)"
      t.column "bug_id", :integer, :null => false,
      :description => "Foreign key to bugs(id)"
      t.column "created_at", :datetime, :null => false, 
      :description => "Creation timestamp."
      t.column "user_id", :integer, :null => false,
      :description => "Foreign key to users(id)"
    end
    
    add_foreign_key "filed_bugs", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "filed_bugs", ["bug_id"], "bugs", ["id"]
    add_foreign_key "filed_bugs", ["user_id"], "users", ["id"]
    add_index "filed_bugs", ["errata_id", "bug_id", "created_at"], :name => "filed_bugs_idx"
    
  end

  def self.down
    drop_table :filed_bugs
  end
end
