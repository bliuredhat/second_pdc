class FiledJiraIssue < ActiveRecord::Base
  include FiledLink
  belongs_to :jira_issue
  alias :target :jira_issue

  validate(:on => :create) do
    advisory_state_ok
    security_valid
    checklist_ok
  end

  after_destroy do
    DroppedJiraIssue.create!(:jira_issue => self.jira_issue,
                             :errata => self.errata,
                             :state_index => self.errata.current_state_index)
  end

  after_create do
    Jira::FiledJiraIssueJob.enqueue self
  end

  private

  def checklist_ok
    JiraIssueEligibility::CheckList.new(jira_issue, :errata => errata, :user => user).result_list.each do |result, message, title|
      errors.add("Issue #{jira_issue.display_id}", message) if !result
    end
  end
end
