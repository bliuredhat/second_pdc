class EnqueueOrgChartSync < ActiveRecord::Migration
  def up
    OrgChart::SyncJob.enqueue_once
  end

  def down
    Delayed::Job.where('handler like "%ruby/object:OrgChart::SyncJob %"').destroy_all
  end
end
