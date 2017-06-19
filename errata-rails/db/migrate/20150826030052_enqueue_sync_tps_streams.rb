class EnqueueSyncTpsStreams < ActiveRecord::Migration
  def up
    Tps::SyncTpsStreams.enqueue_once
  end

  def down
    Delayed::Job.where('handler like "%ruby/object:Tps::SyncTpsStreams %"').destroy_all
  end
end
