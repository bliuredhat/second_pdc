class AddJobCountToJobTracker < ActiveRecord::Migration
  def up
    add_column :job_trackers, :total_job_count, :integer

    # For any existing job trackers, use the current job count as the
    # total.  It's not accurate in the case that jobs have completed,
    # but it's the best we can do.
    JobTracker.update_all('total_job_count = (SELECT COUNT(*) FROM job_tracker_delayed_maps m WHERE m.job_tracker_id=job_trackers.id)')

    # Any job trackers where we just set the total job count to 0 must
    # have completed or permanently failed.  Pretend that they had 1
    # job, since having 0 jobs doesn't make sense and complicates
    # progress calculations
    JobTracker.where(:total_job_count => 0).update_all(:total_job_count => 1)

    # Now that values have been set, make it non-nullable
    change_column :job_trackers, :total_job_count, :integer, :null => false
  end

  def down
    remove_column :job_trackers, :total_job_count
  end
end
