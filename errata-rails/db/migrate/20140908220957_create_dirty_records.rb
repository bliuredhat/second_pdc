class CreateDirtyRecords < ActiveRecord::Migration
  def up
    create_table :dirty_records do |t|
      t.integer :record_id, :null => false, :index => true
      t.string :status, :null => true
      t.string :type, :null => false
      t.datetime :last_updated, :null => false
    end
    # No foreign key for record_id is added to bug/jira_issues because the integrity check will fail
    # if it is a new issue which is not yet created in issues table.
    add_index "dirty_records", ['record_id', 'status'], :name => "dirty_records_id_and_status_idx"
  end

  def down
    drop_table :dirty_records
  end
end
