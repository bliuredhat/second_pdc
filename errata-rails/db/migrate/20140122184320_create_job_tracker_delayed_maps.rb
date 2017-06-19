class CreateJobTrackerDelayedMaps < ActiveRecord::Migration
  def change
    create_table :job_tracker_delayed_maps do |t|
      t.integer :delayed_job_id, :null => false
      t.integer :job_tracker_id, :null => false
      t.timestamps
    end
  end
end
