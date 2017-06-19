class CreateInfoRequests < ActiveRecord::Migration
  def self.up
    create_table :info_requests do |t|
      t.integer :errata_id, :null => false
      t.integer :state_index_id, :null => false
      t.integer :who, :null => false
      t.integer :info_role, :null => false
      t.string  :summary, :null => false
      t.string  :description, :null => false, :limit => 4000
      t.boolean :is_active, :null => false
      t.timestamps
    end
    add_column :comments, :info_request_id, :integer
    add_foreign_key "comments", ["info_request_id"], "info_requests", ["id"]

  end

  def self.down
    remove_column :comments, :info_request_id
    drop_table :info_requests
  end
end
