module Jira
  class FiledJiraIssueJob
    def initialize(id)
      @filed_issue_id = id
    end

    def perform
      filed = FiledJiraIssue.find(@filed_issue_id)
      comment = "This issue has been added to advisory #{filed.errata.advisory_name} by #{filed.who.to_s}"
      jira = Jira::Rpc.get_connection
      jira.add_comment_to_issue(filed.jira_issue, comment, :private => true)
    end

    def self.enqueue(filed_jira_issue)
      Delayed::Job.enqueue self.new(filed_jira_issue.id), 5
    end
  end
end
