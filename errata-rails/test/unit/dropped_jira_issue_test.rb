require 'test_helper'
require 'jira/rpc'

class DroppedJiraIssueTest < ActiveSupport::TestCase
  test "Security Bug Removal" do
    e = RHSA.new()
    JiraIssue.any_instance.stubs(:is_security_restricted?).returns(true)
    filed = FiledJiraIssue.new(:errata => e, :jira_issue => JiraIssue.first)
    dropped = DroppedJiraIssue.new(:errata => e, :jira_issue => filed.jira_issue, :who => qa_user)
    refute dropped.valid?, "Should not be able to drop bug!"
    assert_errors_include(dropped, 'Jira issue Only the Security Team can remove security JIRA Issues from an advisory')

    dropped = DroppedJiraIssue.new(:errata => e, :jira_issue => filed.jira_issue, :who => secalert_user)
    assert_valid dropped
  end

  test "comment posted" do
    force_sync_delayed_jobs(/Jira/) do
      e = RHBA.find(16654)
      dropped = DroppedJiraIssue.new(:jira_issue => JiraIssue.first, :errata => e, :state_index => e.current_state_index)
      expected_comment = /This issue has been dropped from advisory #{Regexp.escape(e.advisory_name)} by /
      Jira::ErrataClient.any_instance.expects(:add_comment_to_issue).with(JiraIssue.first, regexp_matches(expected_comment), :private => true)
      dropped.save!
    end
  end

  test "jira issues are dropped when advisory is dropped" do
    e = RHBA.find(7517)

    filed = e.filed_jira_issues
    dropped = DroppedJiraIssue.where(:errata_id => e)

    refute filed.empty?, 'test data problem: expected advisory to have JIRA issues'
    assert dropped.empty?, 'test data problem: expected advisory to have no dropped JIRA issues'

    issue_ids = filed.map(&:jira_issue_id).sort

    e.change_state!('DROPPED_NO_SHIP', admin_user, 'dropped for test of DroppedJiraIssue')

    [filed, dropped].each(&:reload)

    assert filed.empty?, "FiledJiraIssue remain after DROPPED_NO_SHIP: #{filed.to_a.inspect}"
    refute dropped.empty?, "DroppedJiraIssue missing after DROPPED_NO_SHIP"

    # every filed issue should have become dropped
    dropped_ids = dropped.map(&:jira_issue_id).sort
    assert_equal issue_ids, dropped_ids, "Mismatch between filed and dropped JIRA issues"
  end
end
