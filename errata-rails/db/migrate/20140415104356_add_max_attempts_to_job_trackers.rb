class AddMaxAttemptsToJobTrackers < ActiveRecord::Migration
  def change
    add_column :job_trackers, :max_attempts, :integer, :null => true
  end
end
