json.array! @errata.jira_issues do |issue|
  json.partial! "/jira_issues/jira_issue", :jira_issue => issue
end
