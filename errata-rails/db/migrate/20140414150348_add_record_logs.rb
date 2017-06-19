class AddRecordLogs < ActiveRecord::Migration
  def self.up
    create_table :record_logs do |t|
      t.string :message, :null => false
      t.string :severity, :null => false
      t.integer :record_id, :null => false
      t.string :type, :null => false
      t.integer :user_id, :null => true
      t.datetime :created_at, :null => false
    end
  end

  def self.down
    drop_table :record_logs
  end
end
