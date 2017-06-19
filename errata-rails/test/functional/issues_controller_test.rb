require 'test_helper'

class IssuesControllerTest < ActionController::TestCase
  test "index OK" do
    auth_as admin_user

    get :index
    assert_response :success
    assert_match /\bBug Search\b/, response.body
  end

  test "find with bug ID" do
    auth_as admin_user

    b = Bug.find(459581)
    post :find_errata_for_issue, :issue => {:id_or_key => b.bug_id}
    assert_redirected_to :controller => :bugs, :action => :errata_for_bug, :id => b.bug_id
  end

  test "find with bug alias" do
    auth_as admin_user

    b = Bug.find_by_alias('CVE-2009-3560')
    post :find_errata_for_issue, :issue => {:id_or_key => b.alias}
    assert_redirected_to :controller => :bugs, :action => :errata_for_bug, :id => b.bug_id
  end

  test "find with issue key" do
    auth_as admin_user

    j = JiraIssue.find_by_key('MAITAI-1229')
    post :find_errata_for_issue, :issue => {:id_or_key => j.key}
    assert_redirected_to :controller => :jira_issues, :action => :errata_for_issue, :key => j.key
  end

  test "find with nonexistent bug alias displays expected error message" do
    auth_as admin_user

    post :find_errata_for_issue, :issue => {:id_or_key => 'this-thing-does-not-exist'}
    assert_match %r{^No such bug or JIRA issue this-thing-does-not-exist\b}, flash[:error]
    assert_redirected_to :action => :index
  end

  test "find with nonexistent issue key displays expected error message" do
    auth_as admin_user

    post :find_errata_for_issue, :issue => {:id_or_key => 'XYZ-998'}
    assert_match %r{^No such bug or JIRA issue XYZ-998\b}, flash[:error]
    assert_redirected_to :action => :index
  end

  test "find with nonexistent bug number displays expected error message" do
    auth_as admin_user

    post :find_errata_for_issue, :issue => {:id_or_key => '9999998'}
    assert_match %r{^No such bug or JIRA issue 9999998\b}, flash[:error]
    assert_redirected_to :action => :index
  end

  test "check bug advisory eligibility with valid bug id" do
    auth_as admin_user
    bug_id = Bug.first.id

    post :troubleshoot, :issue => bug_id
    assert_redirected_to :controller => :bugs, :action => :troubleshoot, :bug_id => bug_id
  end

  test "check bug advisory eligibility with jira issue id" do
    auth_as admin_user
    jira_issue_key = JiraIssue.first.key

    post :troubleshoot, :issue => jira_issue_key
    assert_equal 'Troubleshooter is not available for jira issues', flash[:error]
    assert_redirected_to :action => :index
  end

  test "check bug advisory eligibility with invalid bug format" do
    auth_as admin_user
    invalid_bug = 'Blah_Blah_123'

    post :troubleshoot, :issue => invalid_bug
    assert_equal "Bad bug id format: #{invalid_bug}", flash[:error]
    assert_redirected_to :action => :index
  end

  def create_issue(type, data)
    if type == 'jira'
      JiraIssue.new(:key => data[:key], :id_jira => data[:id], :summary => 'Test issue', :status => 'Open', :priority => 'Minor')
    elsif type == 'bugzilla'
      bug = Bug.new(:short_desc => 'Test bug', :bug_status => 'MODIFIED')
      bug.id = data[:id]
      bug
    else
      raise ArgumentError, "Invalid issue type."
    end
  end

  test "sync issues" do
    auth_as admin_user

    jira_issues = []
    bugs = []

    jira_id = 10000
    ['ABC-12345', 'BC2-345'].each do |key|
      jira_id +=1
      jira_issues << create_issue('jira', {:key => key, :id_jira => jira_id})
    end

    ['123456', '654321'].each do |bug_id|
      bugs << create_issue('bugzilla', {:id => bug_id})
    end

    # stub the following methods as we don't want to repeat the test
    JiraIssue.stubs(:batch_update_from_rpc).returns(jira_issues)
    Bug.stubs(:batch_update_from_rpc).returns(bugs)

    post :sync_issue_list, :issue_list => '123456 654321 ABC-12345 BC2-345 INVALID_ISSUE'

    assert_response :success
    assert_match /2 issues were synced with JIRA/, flash[:notice]
    assert_match /2 bugs were synced with Bugzilla/, flash[:notice]
    assert_match /1 invalid issues were found/, flash[:error]

    bugs.each do |bug|
      assert_match %Q[<li><a href="/issues/troubleshoot?issue=#{bug.id}">#{bug.id}</a> - Test bug</li>], response.body
    end

    jira_issues.each do |issue|
      assert_match /#{issue.key} - #{issue.summary}/, response.body
    end

    assert_match /<h3>Invalid Issues<\/h3>\s*<ul>\s*<li>INVALID_ISSUE<\/li>\s*<\/ul>/, response.body
  end

  test "sync empty issues" do
    auth_as admin_user

    post :sync_issue_list, :issue_list => ''

    assert_match "No valid bugs/issues found", flash[:error]
  end
end
