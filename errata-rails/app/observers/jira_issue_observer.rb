class JiraIssueObserver < ActiveRecord::Observer
  observe JiraIssue

  def after_save(jira_issue)
    # mark the jira issue as clean
    jira_issue.dirty_jira_issues.each(&:mark_as_clean)
  end
end
