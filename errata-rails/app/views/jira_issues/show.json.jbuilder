json.jira_issue do
  json.partial! '/jira_issues/jira_issue', :jira_issue => @jira_issue
end
