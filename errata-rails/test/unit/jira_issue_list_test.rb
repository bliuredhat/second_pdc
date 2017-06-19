require 'test_helper'

class JiraIssueListTest < ActiveSupport::TestCase
  include Jira

  setup do
    @rhba = RHBA.find(10808)
  end

  def get_jira_issue_list(advisory)
    JiraIssueList.new(advisory.jira_issues.map(&:key).join(','), advisory)
  end

  test "get issues" do
    jira_issues = get_jira_issue_list(@rhba)
    assert_equal jira_issues.list.size, 3
  end

  test "correct mapping of jira issues" do
    expected_issues = JiraIssue.all.take(2).map(&:key)
    jira_issues = JiraIssueList.new(expected_issues.join(' '), RHBA.first)
    assert_equal expected_issues.join(','), jira_issues.keys
  end

  test "add jira issue" do
    jira_issues = get_jira_issue_list(@rhba)
    assert jira_issues.valid?

    to_be_appended = JiraIssue.unfiled.last.key
    jira_issues.append(to_be_appended)

    assert jira_issues.valid?
    assert_difference('@rhba.jira_issues.count') do
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        jira_issues.save!
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal 'JIRA', mail['X-ErrataTool-Component'].value
    assert_equal 'ADDED', mail['X-ErrataTool-Action'].value

    # Make sure rpc is called if the issue is not exist in errata
    JiraIssueList.any_instance.expects(:fetch_jira_issues_via_rpc).once.with(
      all_of(includes('INVALID-99999')))
    jira_issues.append('INVALID-99999')
  end

  test "remove jira issue" do
    jira_issues = get_jira_issue_list(@rhba)
    assert_difference('@rhba.jira_issues.count', -1) do
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        jira_issues.remove(@rhba.jira_issues.last.key)
        jira_issues.save!
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal 'JIRA', mail['X-ErrataTool-Component'].value
    assert_equal 'REMOVED', mail['X-ErrataTool-Action'].value
  end

end
