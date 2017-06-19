module Jira
  class CloseIssueJob
    def initialize(filed_jira_issue_id)
      @filed_jira_issue_id = filed_jira_issue_id
    end

    def self.can_perform?(errata)
      true
    end
    
    def perform
      f = FiledJiraIssue.find @filed_jira_issue_id, :include => [:jira_issue, :errata]
      (issue,errata) = [f.jira_issue,f.errata]
      return unless self.class.can_perform?(errata)
      rpc = Jira::Rpc.get_connection
      if issue.can_close?
        rpc.close_issue_or_comment(issue, errata)
      elsif issue.is_security?
        rpc.add_security_resolve_comment(issue, errata)
      end
    end
    
    def self.close_issues(errata)
      return unless self.can_perform?(errata)
      closeable = errata.filed_jira_issues.select do |f|
        issue = f.jira_issue
        issue.can_close? || issue.is_security?
      end
      closeable.each { |f| enqueue(f.id) }
    end
    
    def self.enqueue(filed_issue_id)
      Delayed::Job.enqueue CloseIssueJob.new(filed_issue_id), 2
    end
  end
end
