class DirtyRecordObserver < ActiveRecord::Observer
  observe DirtyRecord

  def after_create(dirty_record)
    if dirty_record.kind_of?(DirtyBug)
      job_handler = Bugzilla::UpdateDirtyBugsJob
    elsif dirty_record.kind_of?(DirtyJiraIssue)
      job_handler = Jira::UpdateDirtyIssuesJob
    else
      raise ArgumentError, "Invalid dirty record type '#{dirty_record.class.name}'."
    end

    dirty_job = Delayed::Job.where("handler like ?", "%#{job_handler}%").first

    unless dirty_job
     job_handler.enqueue_once
    end
  end
end