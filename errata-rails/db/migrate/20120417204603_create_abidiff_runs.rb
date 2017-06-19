class CreateAbidiffRuns < ActiveRecord::Migration
  def self.up
    create_table :abidiff_runs do |t|
      t.integer :errata_id, :null => false
      t.integer :brew_build_id, :null => false
      t.string :status, :null => false
      t.boolean :current, :null => false, :default => true
      t.datetime :timestamp, :null => false
      t.timestamps
      t.string :result
      t.string :message
    end
  end

  def self.down 
   drop_table :abidiff_runs
  end
end
