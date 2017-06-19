require 'message_bus'
module Jira
  class UpdateIssuesJob
    include SyncIssues

    SYNC_TYPE = :jira_sync

    def perform
      MessageBus.reconcile(SYNC_TYPE) do |since, now|
        update_since = if since
          since
        else
          # arbitrarily picked interval for initial sync.
          # We want to pull in a fairly large set of issues to exercise the system
          # and ensure performance is OK for the issues most likely to be used.
          # This should be fast enough to finish within minutes, not hours.
          6.months.ago
        end

        ok_issues = []
        outdated_issues = []

        with_checkpoints(SYNC_TYPE, update_since, now, JIRALOG) do |from_date, to_date|
          # have to use "real" now, not the time at which the job started, otherwise
          # the calculation will drift across checkpoints
          diff_now = Time.now
          # include a 5 minute overlap with the previous window to protect against drift
          from_minutes = (diff_now - from_date) / 60 + 5
          to_minutes = (diff_now - to_date) / 60
          # "updated >= -10minutes" means issues updated within the last 10 minutes
          jql = "updated > -#{from_minutes.to_i}minutes AND updated <= #{to_minutes.to_i}minutes"

          options = {:fields => %w{id updated}, :expand => []}

          JiraIssue.batch_update_search(jql, options).each do |jql_issue|
            our_issue = JiraIssue.find_by_id_jira(jql_issue.id)

            if our_issue.nil? || our_issue.updated != Time.parse(jql_issue.updated)
              DirtyJiraIssue.mark_as_dirty!(jql_issue.id)
              outdated_issues << jql_issue
            else
              ok_issues << jql_issue
            end
          end
        end

        JIRALOG.info "#{ok_issues.length} JIRA issues are already up-to-date. #{outdated_issues.length} JIRA issues are outdated."
      end
    end

    def next_run_time
      5.minutes.from_now
    end

    def rerun?
      true
    end

    def self.enqueue
      Delayed::Job.enqueue self.new, 5
    end
  end
end
