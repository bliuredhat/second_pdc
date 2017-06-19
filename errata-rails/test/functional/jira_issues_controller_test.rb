require 'test_helper'

class JiraIssuesControllerTest < ActionController::TestCase
  TEST_ISSUE = {
    'summary' => 'add external ping test to network_basic_ops',
    'is_private' => false,
    'key' => 'RHOS-440',
    'status' => 'Resolved',
    'id_jira' => 19382,
    'labels' => %w{LabelA LabelB}
  }

  test "issue show json" do
    auth_as admin_user

    get :show, :key => 'RHOS-440', :format => 'json'
    with_json_response do |obj|
      assert_equal( {'jira_issue' => TEST_ISSUE}, obj)
    end
  end

  test "advisories for issue" do
    auth_as admin_user

    get :errata_for_issue, :key => 'RHOS-440', :format => 'json'

    with_json_response do |obj|
      assert_equal 1, obj.size
      assert_equal 'RHBA-2011:11020', obj[0]['advisory_name']
    end
  end

  test "issues for advisory" do
    auth_as admin_user

    get :for_errata, :id => 11020, :format => 'json'

    with_json_response do |obj|
      assert_equal [TEST_ISSUE], obj
    end
  end

  def with_json_response
    with_failure_message(lambda{"response: #{response.body}"}) do
      assert_response :success
      yield JSON.parse(response.body)
    end
  end

  test "remove issues from advisory" do
    auth_as admin_user

    errata = RHBA.find(10808)
    to_be_removed = {}
    keys = []
    errata.jira_issues.each do |issue|
      to_be_removed[issue.id] = 1
      keys << issue.key
    end

    post :remove_jira_issues_from_errata, :id => 10808, :jira_issue => to_be_removed

    # redirect to advisory view page
    assert_response :redirect
    keys.each do |key|
      assert_match /^Removed.+#{key}/, flash[:notice]
    end
  end

  test "remove empty list" do
    auth_as admin_user

    errata = RHBA.find(10808)
    issue_list = {}
    errata.jira_issues.each do |issue|
      # 0 means not checked
      issue_list[issue.id] = 0
    end

    post :remove_jira_issues_from_errata, :id => 10808, :jira_issue => issue_list

    # redirect to advisory view page
    assert_response :redirect
    assert_match /No JIRA issue has been removed/, flash[:alert]
  end

  test 'can display issues for an advisory' do
    e = RHBA.find(7517)
    assert e.filed_jira_issues.length >= 2, 'test data problem: advisory expected to have at least two jira issues'

    auth_as qa_user

    get :for_errata, :id => e.id
    assert_response :success, response.body

    e.filed_jira_issues.each do |fb|
      assert_match %r{\b#{fb.jira_issue.display_id}\b}, response.body, response.body
    end
  end
end
