module JiraIssuesCommonTest
  def to_test_rpc_issue(jira_issue, updated)
    out          = TestRpcJiraIssue.new
    out.id       = jira_issue.id_jira
    out.key      = jira_issue.key
    out.summary  = jira_issue.summary
    out.updated  = updated.to_s(:db)
    out.status   = Status.new(jira_issue.status)
    out.priority = Priority.new(jira_issue.priority)
    out.fields['labels'] << jira_issue.summary
    out
  end

  class TestRpcJiraIssue < Struct.new(:id, :updated, :key, :summary, :status, :priority)
    attr_accessor :fields

    def initialize
      @fields = Hash.new{|h,k| h[k] = []}
      @fields['security'] = nil
    end
  end

  class Priority < Struct.new(:name)
  end

  class Status < Struct.new(:name)
  end
end