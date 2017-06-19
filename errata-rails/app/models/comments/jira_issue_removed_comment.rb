class JiraIssueRemovedComment < Comment

  def delivery_method
    :jira_issue_removed
  end

end
