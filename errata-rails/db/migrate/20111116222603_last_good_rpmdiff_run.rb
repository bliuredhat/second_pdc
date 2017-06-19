class LastGoodRpmdiffRun < ActiveRecord::Migration
  def self.up
    add_column :rpmdiff_runs, :last_good_run_id, :integer
    add_foreign_key 'rpmdiff_runs', 'last_good_run_id', 'rpmdiff_runs', 'run_id'
  end

  def self.down
    remove_column :rpmdiff_runs, :last_good_run_id
  end
end
