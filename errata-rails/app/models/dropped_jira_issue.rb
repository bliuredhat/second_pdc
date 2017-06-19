class DroppedJiraIssue < ActiveRecord::Base
  include DroppedLink
  belongs_to :jira_issue
  alias :target :jira_issue

  after_create do
    Jira::DroppedJiraIssueJob.enqueue self
  end
end
