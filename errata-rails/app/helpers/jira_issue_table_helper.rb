#
# These are JIRA helper methods for use with the bz_table shared partial.
# See app/views/shared/_bz_table.html.erb.
# It uses some common methods from app/helpers/bz_table_helper.rb.
#
module JiraIssueTableHelper
  include BzTableHelper

  def headings_for_errata_jira_issue
    ["#{JiraIssue.readable_name} Key", 'Priority', 'Status', 'Last Updated', 'Summary', 'Private?']
  end

  def jira_priority_tag(priority)
    return priority unless priority.nil?
    content_tag('span', '(unset)', :class => 'tiny superlight')
  end

  def row_for_errata_jira_issue(jira_issue)
    r = [
      tablesort_helper(jira_issue_link(jira_issue), jira_issue.key),
      tablesort_helper(jira_priority_tag(jira_issue.priority), jira_issue.priority),
      tablesort_helper(jira_issue.status, jira_issue.status),
      sortable_time_ago_in_words(jira_issue.updated),
      h(jira_issue.summary),
    ]
    r << (jira_issue.is_private? ? '<span class="tiny red bold">PRIVATE</span>' : '<span class="tiny superlight">public</span>').html_safe
    if jira_issue.is_private?
      { :content => r, :options => { :extra_class => "bz_private" } }
    else
      r
    end
  end
end
