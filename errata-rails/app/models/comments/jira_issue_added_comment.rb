class JiraIssueAddedComment < Comment

  def delivery_method
    :jira_issue_added
  end

end

