class CronToDelayedJobs < ActiveRecord::Migration
  def up
    Push::RelPrepToPushReadyJob.enqueue_once
  end

  def down
    Delayed::Job.where('handler LIKE "%Push::RelPrepToPushReadyJob%"').delete_all
  end
end
