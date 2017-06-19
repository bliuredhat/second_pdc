class AddUpdateReleasesJob < ActiveRecord::Migration
  def up
    Bugzilla::UpdateReleasesJob.enqueue_once
  end

  def down
    Delayed::Job.where('handler like "%Bugzilla::UpdateReleasesJob %"').destroy_all
  end
end
