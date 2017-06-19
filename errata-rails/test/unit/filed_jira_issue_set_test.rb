require 'test_helper'

class FiledJiraIssueSetTest < ActiveSupport::TestCase

  test "filed jira issue set" do
    e = Errata.where('status != ?', 'NEW_FILES').first
    fbs = FiledJiraIssueSet.new(:jira_issues => [], :errata => e)
    assert fbs.valid?

    # it should validate each issue
    fbs = FiledJiraIssueSet.new(:jira_issues => JiraIssue.unfiled.where(:jira_security_level_id => nil)[0..1], :errata => e)
    refute fbs.valid?

    errors = fbs.errors.full_messages
    assert_equal 2, errors.size
    assert_equal errors[0], errors[1]
    assert_match /\bCannot add or remove non-security bugs unless in NEW_FILES state\b/, errors[0]
  end

end
