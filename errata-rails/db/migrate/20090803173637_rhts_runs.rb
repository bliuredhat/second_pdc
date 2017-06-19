class RhtsRuns < ActiveRecord::Migration

  def self.up
    create_table :rhts_runs do |t|
      t.integer :errata_id, :null => :false
      t.integer :user_id, :null => :false
      t.timestamps
    end
    add_foreign_key 'rhts_runs', ['errata_id'], 'errata_main', ['id']
    add_foreign_key 'rhts_runs', ['user_id'], 'users', ['id']
  end

  def self.down
    drop_table :rhts_runs
  end
end
