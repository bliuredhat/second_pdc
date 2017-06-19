class EnqueueUpdateIssuesJob < ActiveRecord::Migration
  def up
    Jira::UpdateIssuesJob.enqueue
  end

  def down
    Delayed::Job.where('handler like "%ruby/object:Jira::UpdateIssuesJob %"').destroy_all
  end
end
