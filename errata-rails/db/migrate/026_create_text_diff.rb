class CreateTextDiff < ActiveRecord::Migration

  
  def self.up
    create_table :text_diffs, 
    :description => 'Stores diffs between errata text revisions. Replaces errata_activites usage for diffs' do |t|
      t.column "errata_id", :integer, :null => false,
      :description => "Foreign key to errata_main(id)"
      t.column "user_id",           :integer,                  :null => false,
      :description => 'Foreign key to users(id). References whom committed the activity'
      t.column "created_at", :datetime,                 :null => false,
      :description => 'When did the activity occur?'
      t.column "old_id", :integer, :description => 'Old errata_activities id'
      t.column "diff",           :text,                :null => false,
      :description => 'Text diff from prior revision'
    end
    
    add_foreign_key "text_diffs", ["errata_id"], "errata_main", ["id"]
    add_foreign_key "text_diffs", ["user_id"], "users", ["id"]

    add_index "text_diffs", ["errata_id" ,"created_at"], :name => "text_diff_idx"
    add_index "text_diffs", ["old_id"], :name => "text_diff_old_id_idx"
  end

  def self.down
    drop_table :text_diffs
  end
end
