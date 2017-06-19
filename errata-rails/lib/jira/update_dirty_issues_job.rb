module Jira
  class UpdateDirtyIssuesJob

    def perform
      dirty_issue_ids = DirtyJiraIssue.engage.sort
      return if dirty_issue_ids.empty?

      JIRALOG.info "Updating #{dirty_issue_ids.size} dirty issues..."

      query = "id in (#{dirty_issue_ids.join ', '})"

      # validateQuery false prevents the server from complaining if
      # we queried for issues which don't exist.  That can happen if
      # an issue was synced to Errata Tool and later deleted.  In
      # such a case, we consider the "update" successful although
      # the issue is not actually updated.
      #
      # If bug 1168479 were implemented, deleted issues would
      # probably be handled somehow here.
      begin
        JiraIssue.batch_update_from_jql(query, validateQuery: false)
      rescue => e
        JIRALOG.error "UpdateDirtyIssuesJob: batch update failed - query: #{query} error: #{e}"
        return
      end

      failed_sync = DirtyJiraIssue.where(record_id: dirty_issue_ids, status: :engaged)
                                  .select(:record_id)

      if failed_sync.any?
        failed_issue_ids = failed_sync.pluck(:record_id).sort.join(', ')
        JIRALOG.error "UpdateDirtyIssuesJob: failed to sync [#{failed_issue_ids}] "
        JIRALOG.warn  "UpdateDirtyIssuesJob: deleting failed issues [#{failed_issue_ids}]"
        failed_sync.delete_all
      end
      JIRALOG.info "Done update."
    end

    def next_run_time
      Time.now + Settings.jira_dirty_update_delay
    end

    def rerun?
      DirtyJiraIssue.any?
    end

    def self.enqueue_once
      obj = self.new
      Delayed::Job.enqueue_once obj, 0, obj.next_run_time
    end
  end
end
