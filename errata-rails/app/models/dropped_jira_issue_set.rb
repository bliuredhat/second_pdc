class DroppedJiraIssueSet < LinkSetBase
  def initialize(params = {})
    @issues = params[:jira_issues]
    @errata = params[:errata]
    super(
      :new_link => lambda {|issue,errata| DroppedJiraIssue.new(:errata => errata, :jira_issue => issue)},
      :link_type => 'JIRA issue',
      :operation => 'removed',
      :targets => @issues,
      :errata => @errata,
      :persist_links => lambda {|issues| @errata.filed_jira_issues.where(:jira_issue_id => issues).destroy_all }
    )
  end

  def comment_class
    JiraIssueRemovedComment
  end
end
