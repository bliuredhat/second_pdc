class AddStateIndexToFiledBugs < ActiveRecord::Migration
  def self.up
    add_column :filed_bugs, :state_index_id, :integer
    add_foreign_key "filed_bugs", ["state_index_id"], "state_indices", ["id"]
  end

  def self.down
    drop_column :filed_bugs, :state_index_id
  end
end
