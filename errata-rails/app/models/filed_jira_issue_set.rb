class FiledJiraIssueSet < LinkSetBase
  def initialize(params = {})
    @issues = params[:jira_issues]
    @errata = params[:errata]
    super(
      :new_link => lambda {|issue,errata| FiledJiraIssue.new(:jira_issue => issue, :errata => errata)},
      :link_type => 'JIRA issue',
      :targets => @issues,
      :errata => @errata
    )
  end

  def comment_class
    JiraIssueAddedComment
  end
end
