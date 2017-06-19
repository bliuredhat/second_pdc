class CreateStateIndices < ActiveRecord::Migration
  def self.up
    create_table :state_indices do |t|
      t.integer :errata_id, :null => false
      t.string  :current, :null => false
      t.string  :previous, :null => false
      t.integer :who, :null => false
      t.timestamps
    end
    add_column :errata_main, :current_state_index_id, :integer
    add_column :comments, :state_index_id, :integer
    add_foreign_key "errata_main", ["current_state_index_id"], "state_indices", ["id"]
    add_foreign_key "comments", ["state_index_id"], "state_indices", ["id"]
  end

  def self.down
    add_column :errata_main, :state_index_id
    add_column :comments, :state_index_id
    drop_table :state_indices
  end
end
