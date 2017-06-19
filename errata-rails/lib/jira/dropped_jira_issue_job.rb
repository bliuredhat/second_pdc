module Jira
  class DroppedJiraIssueJob
    def initialize(id)
      @dropped_issue_id = id
    end

    def perform
      dropped = DroppedJiraIssue.find(@dropped_issue_id)
      comment = "This issue has been dropped from advisory #{dropped.errata.advisory_name} by #{dropped.who.to_s}"
      jira = Jira::Rpc.get_connection
      jira.add_comment_to_issue(dropped.jira_issue, comment, :private => true)
    end

    def self.enqueue(dropped_jira_issue)
      Delayed::Job.enqueue self.new(dropped_jira_issue.id), 5
    end
  end
end
